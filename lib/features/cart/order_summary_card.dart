import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../checkout/checkout_models.dart';

/// Subtotal, coupon, delivery and total from the server's quote. Used on Cart and Checkout.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = Colors.green.shade700;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _Row('Subtotal (${quote.totalCases} cases)', formatRupees(quote.subtotal)),
            if (quote.couponDiscount > 0)
              _Row('Coupon ${quote.couponCode}', '− ${formatRupees(quote.couponDiscount)}', color: green),
            _Row('Delivery', quote.deliveryCharge == 0 ? 'Free' : formatRupees(quote.deliveryCharge),
                color: quote.deliveryCharge == 0 ? green : null),
            if (quote.amountForFreeDelivery != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Add ${formatRupees(quote.amountForFreeDelivery!)} more for free delivery',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            const Divider(),
            _Row('Total', formatRupees(quote.total), bold: true),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = (bold ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(color: color, fontWeight: bold ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
