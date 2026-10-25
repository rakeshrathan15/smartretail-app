import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_exception.dart';
import '../../core/widgets/error_retry.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../checkout/checkout_providers.dart';
import 'shop_profile_repository.dart';

/// Shop details and map location. [from] is where to continue after saving (after sign-up).
class ShopProfileScreen extends ConsumerWidget {
  const ShopProfileScreen({super.key, this.from});

  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(shopProfileProvider);
    return profile.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: ErrorRetry(message: '$e', onRetry: () => ref.invalidate(shopProfileProvider)),
        ),
      ),
      data: (p) => _ShopProfileForm(initial: p, from: from),
    );
  }
}

class _ShopProfileForm extends ConsumerStatefulWidget {
  const _ShopProfileForm({required this.initial, required this.from});

  final ShopProfile initial;
  final String? from;

  @override
  ConsumerState<_ShopProfileForm> createState() => _ShopProfileFormState();
}

class _ShopProfileFormState extends ConsumerState<_ShopProfileForm> {
  /// Hyderabad, until the shop owner places the pin.
  static const _defaultCenter = LatLng(17.385, 78.4867);

  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();
  late final _shopName = TextEditingController(text: widget.initial.shopName ?? '');
  late final _ownerName = TextEditingController(text: widget.initial.ownerName ?? _user?.fullName ?? '');
  late final _phone = TextEditingController(text: widget.initial.phone ?? _user?.phone ?? '');
  late final _gst = TextEditingController(text: widget.initial.gstNumber ?? '');
  late final _address = TextEditingController(text: widget.initial.address ?? '');
  late final _city = TextEditingController(text: widget.initial.city ?? 'Hyderabad');
  late final _pincode = TextEditingController(text: widget.initial.pincode ?? '');
  late LatLng? _location = widget.initial.location;
  bool _locating = false;
  bool _saving = false;
  String? _locationError;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  UserSummary? get _user => ref.read(authControllerProvider).value;

  bool get _onboarding => widget.from != null;

  @override
  void dispose() {
    for (final c in [_shopName, _ownerName, _phone, _gst, _address, _city, _pincode]) {
      c.dispose();
    }
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final point = await ref.read(currentLocationProvider)();
      if (!mounted) return;
      setState(() => _location = point);
      _mapController.move(point, 17);
    } on LocationUnavailable catch (e) {
      setState(() => _locationError = e.message);
    } catch (_) {
      setState(() => _locationError = 'Could not get your location. Tap your shop on the map instead.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    setState(() => _fieldErrors = const {});
    final valid = _formKey.currentState!.validate();
    final location = _location;
    if (location == null) setState(() => _locationError = 'Place the pin on your shop');
    if (!valid || location == null) return;
    if (location.latitude < 6 || location.latitude > 37.5 || location.longitude < 68 || location.longitude > 98) {
      setState(() => _locationError = 'The pin must be in India');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(shopProfileRepositoryProvider)
          .save(
            shopName: _shopName.text.trim(),
            ownerName: _ownerName.text.trim(),
            phone: _phone.text.trim(),
            gstNumber: _gst.text.trim().isEmpty ? null : _gst.text.trim().toUpperCase(),
            address: _address.text.trim(),
            city: _city.text.trim(),
            pincode: _pincode.text.trim(),
            location: location,
          );
      ref.invalidate(shopProfileProvider);
      // The first save also creates the default delivery address.
      ref.invalidate(addressesProvider);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (!mounted) return;
      if (_onboarding) {
        context.go(widget.from!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${saved.shopName}')));
        context.pop();
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v, String message) => (v == null || v.trim().isEmpty) ? message : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = ref.watch(mapTilesEnabledProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial.complete ? 'Shop profile' : 'Complete your shop profile'),
        automaticallyImplyLeading: !_onboarding,
        actions: [
          // In the top bar so a new shop owner always sees that this step is optional.
          if (_onboarding)
            TextButton(
              onPressed: () => context.go(widget.from!),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Skip for now'),
            ),
        ],
      ),
      // Not a lazy ListView: the form can only check fields that are built, so all of them must be.
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          // Extra room at the bottom so the Save button clears the phone's gesture bar.
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('We need this to deliver orders to your shop.'),
              const SizedBox(height: 16),
              Text('Shop details', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _shopName,
                decoration: InputDecoration(labelText: 'Shop name *', errorText: _fieldErrors['shopName']),
                textCapitalization: TextCapitalization.words,
                validator: (v) => _required(v, 'Enter the shop name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerName,
                decoration: InputDecoration(labelText: 'Owner name *', errorText: _fieldErrors['ownerName']),
                textCapitalization: TextCapitalization.words,
                validator: (v) => _required(v, 'Enter the owner name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: InputDecoration(
                  labelText: 'Mobile *',
                  prefixText: '+91 ',
                  errorText: _fieldErrors['phone'],
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final digits = (v ?? '')
                      .replaceAll(RegExp(r'\D'), '')
                      .replaceFirst(RegExp(r'^(91|0)(?=\d{10}$)'), '');
                  return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? null : 'Enter a valid 10-digit mobile number';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gst,
                decoration: InputDecoration(
                  labelText: 'GSTIN (optional)',
                  helperText: 'For GST invoices',
                  errorText: _fieldErrors['gstNumber'],
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 15,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  return RegExp(
                        r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
                        caseSensitive: false,
                      ).hasMatch(value)
                      ? null
                      : 'A GSTIN has 15 characters, e.g. 36ABCDE1234F1Z5';
                },
              ),
              const SizedBox(height: 16),
              Text('Shop location', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text('Tap your shop on the map, or use your current location while at the shop.'),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 260,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _location ?? _defaultCenter,
                      initialZoom: _location == null ? 12 : 17,
                      onTap: (_, point) => setState(() {
                        _location = point;
                        _locationError = null;
                      }),
                    ),
                    children: [
                      if (tiles)
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.smartretail.smart_retail_app',
                        ),
                      if (_location != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _location!,
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                                semanticLabel: 'Shop pin',
                              ),
                            ),
                          ],
                        ),
                      if (tiles) const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _useMyLocation,
                    icon: _locating
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    label: Text(_locating ? 'Finding you…' : 'Use my current location'),
                  ),
                  Text(
                    _location == null
                        ? 'No pin yet'
                        : '${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_locationError!, style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: InputDecoration(
                  labelText: 'Address / landmark *',
                  hintText: 'Shop no., street, area, landmark',
                  errorText: _fieldErrors['address'],
                ),
                validator: (v) => _required(v, 'Enter the shop address'),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      decoration: InputDecoration(labelText: 'City *', errorText: _fieldErrors['city']),
                      validator: (v) => _required(v, 'Enter the city'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _pincode,
                      decoration: InputDecoration(labelText: 'PIN code *', errorText: _fieldErrors['pincode']),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : 'Enter 6 digits',
                    ),
                  ),
                ],
              ),
              if (_error != null && _fieldErrors.isEmpty)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.initial.complete ? 'Save changes' : 'Save shop profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
