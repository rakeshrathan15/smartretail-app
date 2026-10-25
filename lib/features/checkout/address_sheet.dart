import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import 'checkout_models.dart';
import 'checkout_providers.dart';
import 'checkout_repository.dart';

/// Bottom sheet to add a delivery address. Returns the saved address.
Future<Address?> showAddAddressSheet(BuildContext context) {
  return showModalBottomSheet<Address>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _AddressForm(),
  );
}

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm();

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController(text: 'Hyderabad');
  final _pincode = TextEditingController();
  String _label = 'Shop';
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    for (final c in [_name, _phone, _line1, _line2, _city, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _fieldErrors = const {});
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final address = await ref.read(checkoutRepositoryProvider).addAddress(AddressInput(
            label: _label,
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            addressLine1: _line1.text.trim(),
            addressLine2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
            city: _city.text.trim(),
            pincode: _pincode.text.trim(),
          ));
      ref.invalidate(addressesProvider);
      if (mounted) Navigator.of(context).pop(address);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String message) => (value == null || value.trim().isEmpty) ? message : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New delivery address', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final label in const ['Shop', 'Godown', 'Home'])
                    ChoiceChip(label: Text(label), selected: _label == label, onSelected: (_) => setState(() => _label = label)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: 'Contact name', errorText: _fieldErrors['fullName']),
                textCapitalization: TextCapitalization.words,
                validator: (v) => _required(v, 'Enter a contact name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: InputDecoration(labelText: 'Mobile', prefixText: '+91 ', errorText: _fieldErrors['phone']),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? null : 'Enter a valid 10-digit mobile number';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _line1,
                decoration: InputDecoration(labelText: 'Shop no., building, street', errorText: _fieldErrors['addressLine1']),
                validator: (v) => _required(v, 'Enter the address'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _line2,
                decoration: const InputDecoration(labelText: 'Area, landmark (optional)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      decoration: InputDecoration(labelText: 'City', errorText: _fieldErrors['city']),
                      validator: (v) => _required(v, 'Enter the city'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _pincode,
                      decoration: InputDecoration(labelText: 'PIN code', errorText: _fieldErrors['pincode']),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '') ? null : 'Enter 6 digits',
                    ),
                  ),
                ],
              ),
              if (_error != null && _fieldErrors.isEmpty)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
