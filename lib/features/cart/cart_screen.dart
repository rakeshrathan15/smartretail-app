import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/product_thumb.dart';
import '../checkout/checkout_models.dart';
import '../checkout/checkout_providers.dart';
import 'cart_controller.dart';
import 'order_summary_card.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    final quoteState = ref.watch(quoteProvider);
    // Keep showing the last prices while a new quote loads, so the screen doesn't flicker.
    final quote = quoteState.value;

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text('Your cart is empty', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text('Add cases from the shop to see bulk prices here.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => context.go('/shop'), child: const Text('Browse products')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Cart (${lines.length} ${lines.length == 1 ? 'product' : 'products'})'),
        bottom: quoteState.isLoading
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (quoteState.hasError && quote == null)
            ErrorRetry(message: '${quoteState.error}', onRetry: () => ref.invalidate(quoteProvider)),
          for (final line in lines) _CartLineTile(line: line, priced: quote?.lineFor(line.productId)),
          const SizedBox(height: 12),
          const _CouponBox(),
          const SizedBox(height: 12),
          if (quote != null) OrderSummaryCard(quote: quote),
          if (quote != null && quote.problems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ProblemsBox(problems: quote.problems),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: quote != null && quote.canPlaceOrder && !quoteState.isLoading
                ? () => context.push('/checkout')
                : null,
            child: Text(quote == null ? 'Checking prices…' : 'Checkout · ${formatRupees(quote.total)}'),
          ),
        ),
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line, required this.priced});

  final CartLine line;
  final QuoteLine? priced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cart = ref.read(cartProvider.notifier);
    final p = priced;
    final bulkApplied = p != null && p.pricePerCase < p.basePrice;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.push('/product/${line.slug}'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 64,
                      child: ProductThumb(imageUrl: line.imageUrl, label: line.brand ?? line.name, iconSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                      Text(packSize(line.unitVolumeMl, line.unitsPerCase), style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      if (p != null)
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            Text('${formatRupees(p.pricePerCase)}/case',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (bulkApplied)
                              Text(formatRupees(p.basePrice),
                                  style: theme.textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough)),
                            if (bulkApplied)
                              Text('Bulk price',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${line.name}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => cart.remove(line.productId),
                ),
              ],
            ),
            Row(
              children: [
                _Stepper(
                  quantity: line.quantity,
                  onChanged: (q) => cart.setQuantity(line.productId, q),
                  label: line.name,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: p == null
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatRupees(p.lineTotal),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                            if (p.saving > 0)
                              Text('You save ${formatRupees(p.saving)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.green.shade700)),
                          ],
                        ),
                ),
              ],
            ),
            if (p?.problem != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(p!.problem!, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
                    if (p.stockAvailable > 0 && p.quantity > p.stockAvailable)
                      TextButton(
                        onPressed: () => cart.setQuantity(line.productId, p.stockAvailable),
                        child: Text('Change to ${p.stockAvailable}'),
                      )
                    else
                      TextButton(onPressed: () => cart.remove(line.productId), child: const Text('Remove')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.quantity, required this.onChanged, required this.label});

  final int quantity;
  final ValueChanged<int> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          visualDensity: VisualDensity.compact,
          tooltip: 'One case less of $label',
          icon: Icon(quantity == 1 ? Icons.delete_outline : Icons.remove, size: 18),
          onPressed: () => onChanged(quantity - 1),
        ),
        SizedBox(
          width: 48,
          child: Text('$quantity', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton.outlined(
          visualDensity: VisualDensity.compact,
          tooltip: 'One case more of $label',
          icon: const Icon(Icons.add, size: 18),
          onPressed: () => onChanged(quantity + 1),
        ),
        const SizedBox(width: 4),
        const Text('cases'),
      ],
    );
  }
}

class _CouponBox extends ConsumerStatefulWidget {
  const _CouponBox();

  @override
  ConsumerState<_CouponBox> createState() => _CouponBoxState();
}

class _CouponBoxState extends ConsumerState<_CouponBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = ref.watch(couponCodeProvider);
    final quote = ref.watch(quoteProvider).value;
    final theme = Theme.of(context);

    if (code != null) {
      final problem = quote?.couponCode == code ? quote?.couponProblem : null;
      final discount = quote?.couponCode == code ? quote?.couponDiscount ?? 0 : 0;
      return Card(
        child: ListTile(
          leading: Icon(Icons.local_offer, color: problem == null ? Colors.green.shade700 : theme.colorScheme.error),
          title: Text(code),
          subtitle: Text(
            problem ?? (discount > 0 ? 'You save ${formatRupees(discount.toDouble())}' : 'Checking…'),
            style: TextStyle(color: problem == null ? Colors.green.shade700 : theme.colorScheme.error),
          ),
          trailing: TextButton(
            onPressed: () {
              _controller.clear();
              ref.read(couponCodeProvider.notifier).set(null);
            },
            child: const Text('Remove'),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Coupon code',
              prefixIcon: Icon(Icons.local_offer_outlined),
              isDense: true,
            ),
            onSubmitted: (value) => ref.read(couponCodeProvider.notifier).set(value),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => ref.read(couponCodeProvider.notifier).set(_controller.text),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _ProblemsBox extends StatelessWidget {
  const _ProblemsBox({required this.problems});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final problem in problems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Expanded(child: Text(problem)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
