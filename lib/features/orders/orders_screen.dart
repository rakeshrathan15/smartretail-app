import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/home_leading.dart';
import '../checkout/checkout_models.dart';
import '../checkout/checkout_providers.dart';

final _dateFormat = DateFormat('d MMM yyyy, h:mm a');

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myOrdersProvider.future),
        child: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [ErrorRetry(message: '$e', onRetry: () => ref.invalidate(myOrdersProvider))]),
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.receipt_long_outlined, size: 64),
                    SizedBox(height: 12),
                    Center(child: Text('No orders yet')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _OrderTile(order: list[i]),
                ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Order ${order.orderNumber}', style: theme.textTheme.titleMedium)),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(_dateFormat.format(order.createdAt), style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('${order.totalCases} cases · ${paymentLabel(order.paymentMethod)} · '
                        '${paymentStatusLabel(order.paymentStatus)}'),
                  ),
                  Text(formatRupees(order.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String paymentLabel(String method) => PaymentMethod.fromApi(method)?.label ?? method;

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      OrderStatus.delivered => (Colors.green.shade100, Colors.green.shade900),
      OrderStatus.cancelled || OrderStatus.returned => (Colors.red.shade100, Colors.red.shade900),
      OrderStatus.placed => (Colors.amber.shade100, Colors.amber.shade900),
      _ => (Colors.blue.shade100, Colors.blue.shade900),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Text(status.label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Order detail; also the screen right after placing an order ([justPlaced]).
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId, this.justPlaced = false});

  final String orderId;
  final bool justPlaced;

  static const _steps = [
    OrderStatus.placed,
    OrderStatus.confirmed,
    OrderStatus.packed,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(order.value == null ? 'Order' : 'Order ${order.value!.orderNumber}'),
        // Right after ordering there is nothing to go back to: the cart is empty.
        automaticallyImplyLeading: !justPlaced,
        leading: justPlaced ? null : backOrHome(context),
      ),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorRetry(message: '$e', onRetry: () => ref.invalidate(orderDetailProvider(orderId))),
        ),
        data: (o) => _buildDetail(context, o),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, OrderDetail o) {
    final theme = Theme.of(context);
    final address = o.address;
    final reached = _steps.indexOf(o.status == OrderStatus.processing || o.status == OrderStatus.shipped
        ? OrderStatus.packed
        : o.status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (justPlaced) ...[
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 72),
          const SizedBox(height: 8),
          Text('Order placed!', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          Text('Order number ${o.orderNumber}', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            o.paymentStatus == 'PENDING_VERIFICATION'
                ? 'We will check your UPI payment and confirm the order.'
                : 'We will confirm your order soon.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => context.go('/orders'), child: const Text('My orders'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () => context.go('/shop'), child: const Text('Keep shopping'))),
            ],
          ),
          const Divider(height: 32),
        ],
        Row(
          children: [
            Expanded(child: Text(_dateFormat.format(o.createdAt), style: theme.textTheme.bodySmall)),
            StatusChip(status: o.status),
          ],
        ),
        if (reached >= 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Icon(i <= reached ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: i <= reached ? Colors.green.shade600 : theme.colorScheme.outline, size: 20),
                      Text(_steps[i].label, textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              for (final item in o.items)
                ListTile(
                  dense: true,
                  title: Text(item.productName),
                  subtitle: Text('${item.quantity} cases × ${formatRupees(item.price)}'),
                  trailing: Text(formatRupees(item.total)),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _line('Subtotal (${o.totalCases} cases)', formatRupees(o.subtotal)),
                    if (o.discount > 0) _line('Coupon ${o.couponCode ?? ''}', '− ${formatRupees(o.discount)}'),
                    _line('Delivery', o.deliveryCharge == 0 ? 'Free' : formatRupees(o.deliveryCharge)),
                    const Divider(),
                    _line('Total', formatRupees(o.total), bold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(paymentLabel(o.paymentMethod)),
            subtitle: Text(paymentStatusLabel(o.paymentStatus)),
          ),
        ),
        if (address != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text('${address['label']} · ${address['fullName']}'),
              subtitle: Text([
                address['addressLine1'],
                ?address['addressLine2'],
                '${address['city']} ${address['pincode']}',
                '+91 ${address['phone']}',
              ].join('\n')),
            ),
          ),
        if (o.notes != null)
          Card(child: ListTile(leading: const Icon(Icons.notes), title: const Text('Note'), subtitle: Text(o.notes!))),
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}
