import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cart/cart_controller.dart';
import 'checkout_models.dart';
import 'checkout_repository.dart';

/// The coupon code the shop owner typed, or null.
final couponCodeProvider = NotifierProvider<CouponCodeController, String?>(CouponCodeController.new);

class CouponCodeController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? code) => state = (code == null || code.trim().isEmpty) ? null : code.trim().toUpperCase();
}

/// The server's price for the current cart and coupon. Re-fetched whenever either changes.
final quoteProvider = FutureProvider<Quote?>((ref) async {
  final lines = ref.watch(cartProvider);
  final coupon = ref.watch(couponCodeProvider);
  if (lines.isEmpty) return null;
  return ref.watch(checkoutRepositoryProvider).quote(lines, coupon);
});

final addressesProvider = FutureProvider<List<Address>>((ref) => ref.watch(checkoutRepositoryProvider).addresses());

final myOrdersProvider = FutureProvider<List<OrderSummary>>(
  (ref) async => (await ref.watch(checkoutRepositoryProvider).myOrders()).items,
);

final orderDetailProvider = FutureProvider.family<OrderDetail, String>(
  (ref, id) => ref.watch(checkoutRepositoryProvider).order(id),
);
