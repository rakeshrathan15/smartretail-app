import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/widgets/error_retry.dart';
import '../auth/auth_controller.dart';
import '../cart/cart_controller.dart';
import '../cart/order_summary_card.dart';
import 'address_sheet.dart';
import 'checkout_models.dart';
import 'checkout_providers.dart';
import 'checkout_repository.dart';

/// Picks the UPI screenshot. Replaceable in tests, where there is no gallery.
final screenshotPickerProvider = Provider<Future<XFile?> Function()>(
  (ref) =>
      () => ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85),
);

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _addressId;
  PaymentMethod _method = PaymentMethod.cod;
  String? _screenshotRef;
  bool _uploading = false;
  bool _placing = false;
  String? _error;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final file = await ref.read(screenshotPickerProvider)();
    if (file == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      // Some pickers give no file name; the server decides the type from the bytes anyway.
      final name = file.name.isEmpty ? 'payment-screenshot.jpg' : file.name;
      final reference = await ref.read(checkoutRepositoryProvider).uploadPaymentScreenshot(await file.readAsBytes(), name);
      setState(() => _screenshotRef = reference);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _placeOrder(Quote quote, String addressId) async {
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final order = await ref
          .read(checkoutRepositoryProvider)
          .placeOrder(
            lines: ref.read(cartProvider),
            couponCode: quote.appliedCoupon,
            addressId: addressId,
            method: _method,
            paymentScreenshot: _method == PaymentMethod.upi ? _screenshotRef : null,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            expectedTotal: quote.total,
          );
      ref.read(cartProvider.notifier).clear();
      ref.read(couponCodeProvider.notifier).set(null);
      ref.invalidate(myOrdersProvider);
      if (mounted) context.go('/order-placed/${order.id}');
    } on ApiException catch (e) {
      // Prices, stock or credit may have changed: fetch a fresh quote so the screen matches the server.
      ref.invalidate(quoteProvider);
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteState = ref.watch(quoteProvider);
    final addresses = ref.watch(addressesProvider);
    final quote = quoteState.value;

    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: quoteState.hasError
              ? ErrorRetry(message: '${quoteState.error}', onRetry: () => ref.invalidate(quoteProvider))
              : const CircularProgressIndicator(),
        ),
      );
    }

    final addressList = addresses.value ?? const <Address>[];
    // Default to the saved default address; keep the choice if it still exists.
    final selected =
        addressList.where((a) => a.id == _addressId).firstOrNull ??
        addressList.where((a) => a.isDefault).firstOrNull ??
        addressList.firstOrNull;
    final credit = quote.credit;
    final creditProblem = credit == null
        ? 'Not enabled for your shop'
        : credit.available < quote.total
        ? 'Only ${formatRupees(credit.available < 0 ? 0 : credit.available)} available'
        : null;
    final needsScreenshot = _method == PaymentMethod.upi && _screenshotRef == null;
    final canPlace =
        quote.canPlaceOrder &&
        selected != null &&
        !needsScreenshot &&
        !(_method == PaymentMethod.credit && creditProblem != null) &&
        !_placing &&
        !_uploading &&
        !quoteState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (ref.watch(authControllerProvider).value?.shopProfileComplete == false)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.store_mall_directory_outlined),
                title: const Text('Add your shop details and location'),
                subtitle: const Text('It helps us deliver to the right place.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/shop-profile'),
              ),
            ),
          _SectionTitle('Deliver to'),
          if (addresses.isLoading && addressList.isEmpty) const LinearProgressIndicator(),
          if (addresses.hasError) Text('${addresses.error}'),
          RadioGroup<String>(
            groupValue: selected?.id,
            onChanged: (id) => setState(() => _addressId = id),
            child: Column(
              children: [
                for (final address in addressList)
                  Card(
                    child: RadioListTile<String>(
                      value: address.id,
                      title: Text('${address.label} · ${address.fullName}'),
                      subtitle: Text('${address.oneLine}\n+91 ${address.phone}'),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final added = await showAddAddressSheet(context);
              if (added != null) setState(() => _addressId = added.id);
            },
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(addressList.isEmpty ? 'Add delivery address' : 'Add another address'),
          ),
          const SizedBox(height: 20),
          _SectionTitle('Payment'),
          Card(
            child: RadioGroup<PaymentMethod>(
              groupValue: _method,
              onChanged: (m) => setState(() => _method = m!),
              child: Column(
                children: [
                  const RadioListTile<PaymentMethod>(
                    value: PaymentMethod.cod,
                    title: Text('Cash on delivery'),
                    subtitle: Text('Pay when the cases arrive'),
                  ),
                  RadioListTile<PaymentMethod>(
                    value: PaymentMethod.upi,
                    enabled: quote.upiId.isNotEmpty,
                    title: const Text('UPI'),
                    subtitle: Text(
                      quote.upiId.isEmpty ? 'Not available right now' : 'Pay now and upload the screenshot',
                    ),
                  ),
                  RadioListTile<PaymentMethod>(
                    value: PaymentMethod.credit,
                    enabled: creditProblem == null,
                    title: const Text('Credit'),
                    subtitle: Text(
                      creditProblem ?? '${formatRupees(credit!.available)} available of ${formatRupees(credit.limit)}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_method == PaymentMethod.upi)
            _UpiBox(
              upiId: quote.upiId,
              amount: quote.total,
              uploading: _uploading,
              attached: _screenshotRef != null,
              onPick: _pickScreenshot,
            ),
          const SizedBox(height: 20),
          _SectionTitle('Order'),
          OrderSummaryCard(quote: quote),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Note for delivery (optional)', isDense: true),
          ),
          for (final problem in quote.problems)
            Text(problem, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shown next to the button so the reason for a refused order is never scrolled away.
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                ),
              FilledButton(
                onPressed: canPlace ? () => _placeOrder(quote, selected.id) : null,
                child: _placing
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        selected == null
                            ? 'Add a delivery address'
                            : needsScreenshot
                            ? 'Upload the UPI screenshot'
                            : 'Place order · ${formatRupees(quote.total)}',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _UpiBox extends StatelessWidget {
  const _UpiBox({
    required this.upiId,
    required this.amount,
    required this.uploading,
    required this.attached,
    required this.onPick,
  });

  final String upiId;
  final double amount;
  final bool uploading;
  final bool attached;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Pay ${formatRupees(amount)} to', style: theme.textTheme.bodyMedium),
            Row(
              children: [
                Expanded(child: SelectableText(upiId, style: theme.textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: upiId));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied')));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('2. Upload the payment screenshot'),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: uploading ? null : onPick,
              icon: uploading
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      attached ? Icons.check_circle : Icons.upload_outlined,
                      color: attached ? Colors.green.shade700 : null,
                    ),
              label: Text(
                uploading
                    ? 'Uploading…'
                    : attached
                    ? 'Screenshot attached · tap to change'
                    : 'Choose screenshot',
              ),
            ),
            const SizedBox(height: 6),
            Text('We confirm the payment before dispatch.', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
