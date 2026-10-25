import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_retail_app/core/api_client.dart';
import 'package:smart_retail_app/core/providers.dart';
import 'package:smart_retail_app/core/token_storage.dart';
import 'package:smart_retail_app/features/auth/auth_controller.dart';
import 'package:smart_retail_app/features/cart/cart_controller.dart';
import 'package:smart_retail_app/features/checkout/checkout_screen.dart';
import 'package:smart_retail_app/main.dart';

import 'fake_backend.dart';

const _cart = CartLine(
  productId: 'id-thums-up-750',
  slug: 'thums-up-750',
  name: 'Thums Up 750ml PET',
  brand: 'Thums Up',
  imageUrl: null,
  unitVolumeMl: 750,
  unitsPerCase: 12,
  quantity: 10,
);

/// A server quote like the real one: ₹420/case, ₹378 from 10 cases, SAVE5 = 5%, delivery ₹500 under ₹5,000,
/// minimum order ₹1,000.
FakeResponse quoteFor(RequestOptions request) {
  final body = request.data as Map<String, dynamic>;
  final items = (body['items'] as List).cast<Map<String, dynamic>>();
  final coupon = body['couponCode'] as String?;
  final lines = [
    for (final item in items)
      () {
        final qty = item['quantity'] as int;
        final price = qty >= 10 ? 378.0 : 420.0;
        return {
          'productId': item['productId'],
          'slug': 'thums-up-750',
          'name': 'Thums Up 750ml PET',
          'brand': 'Thums Up',
          'imageUrl': null,
          'unitsPerCase': 12,
          'quantity': qty,
          'basePrice': 420.0,
          'pricePerCase': price,
          'lineTotal': price * qty,
          'saving': (420 - price) * qty,
          'stockAvailable': 80,
          'problem': qty > 80 ? 'Only 80 cases left' : null,
        };
      }(),
  ];
  final subtotal = lines.fold<double>(0, (sum, l) => sum + (l['lineTotal'] as double));
  final couponOk = coupon == 'SAVE5';
  final discount = couponOk ? (subtotal * 0.05).roundToDouble() : 0.0;
  final delivery = subtotal - discount >= 5000 ? 0.0 : 500.0;
  final problems = <String>[
    if (subtotal < 1000) 'Minimum order is ₹1,000. Add ₹${(1000 - subtotal).round()} more.',
    for (final l in lines)
      if (l['problem'] != null) 'Only 80 cases of Thums Up 750ml PET are left.',
  ];
  return FakeResponse(200, {
    'lines': lines,
    'totalCases': items.fold<int>(0, (sum, i) => sum + (i['quantity'] as int)),
    'subtotal': subtotal,
    'couponCode': coupon,
    'couponDiscount': discount,
    'couponProblem': coupon == null || couponOk ? null : 'This coupon code is not valid',
    'deliveryCharge': delivery,
    'freeDeliveryAbove': 5000,
    'amountForFreeDelivery': delivery > 0 ? 5000 - (subtotal - discount) : null,
    'total': subtotal - discount + delivery,
    'minOrderValue': 1000,
    'storeOpen': true,
    'upiId': 'smartretail@upi',
    'credit': null,
    'problems': problems,
    'canPlaceOrder': problems.isEmpty,
  });
}

final _address = {
  'id': 'addr-1',
  'label': 'Shop',
  'fullName': 'Ravi Kumar',
  'phone': '9876501234',
  'addressLine1': '12 Main Road',
  'addressLine2': null,
  'city': 'Hyderabad',
  'state': 'Telangana',
  'pincode': '500001',
  'isDefault': true,
};

Map<String, dynamic> orderJson(Map<String, dynamic> placed) => {
      'id': 'order-1',
      'orderNumber': 'SR1001',
      'status': 'PLACED',
      'paymentMethod': placed['paymentMethod'],
      'paymentStatus': placed['paymentMethod'] == 'UPI' ? 'PENDING_VERIFICATION' : 'PENDING',
      'paymentTerms': 'PREPAID',
      'subtotal': 3780.0,
      'couponCode': placed['couponCode'],
      'discount': 189.0,
      'deliveryCharge': 500.0,
      'total': placed['expectedTotal'],
      'totalCases': 10,
      'address': {..._address}..remove('id'),
      'notes': null,
      'createdAt': '2026-10-25T10:00:00Z',
      'items': [
        {'productId': 'id-thums-up-750', 'productName': 'Thums Up 750ml PET', 'quantity': 10, 'price': 378.0, 'total': 3780.0},
      ],
    };

class Harness {
  Harness(this.backend, this.cart);

  final FakeBackend backend;
  final InMemoryCartStorage cart;

  Iterable<RequestOptions> calls(String method, String path) =>
      backend.requests.where((r) => r.method == method && r.path == path);
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  List<CartLine> cart = const [],
  Map<String, FakeHandler> routes = const {},
  List<Map<String, dynamic>> addresses = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final tokens = InMemoryTokenStorage();
  await tokens.save(accessToken: 'access-1', refreshToken: 'refresh-1');
  final savedAddresses = [...addresses];
  final cartStorage = InMemoryCartStorage(cart);
  final backend = FakeBackend({
    ...catalogRoutes(),
    'GET /api/me': (_) => FakeResponse(200, userJson()),
    'POST /api/checkout/quote': quoteFor,
    'GET /api/me/addresses': (_) => FakeResponse(200, savedAddresses),
    'POST /api/me/addresses': (req) {
      final created = {..._address, ...(req.data as Map<String, dynamic>), 'id': 'addr-new', 'isDefault': true};
      savedAddresses.add(created);
      return FakeResponse(201, created);
    },
    'POST /api/me/payment-screenshots': (_) => const FakeResponse(201, {'reference': 'payments/abc.png'}),
    'POST /api/orders': (req) => FakeResponse(201, orderJson(req.data as Map<String, dynamic>)),
    'GET /api/me/orders/order-1': (_) => FakeResponse(200, orderJson({'paymentMethod': 'UPI', 'expectedTotal': 4091.0})),
    'GET /api/me/orders': (_) => FakeResponse(200, pageJson([
          {
            'id': 'order-1',
            'orderNumber': 'SR1001',
            'status': 'PLACED',
            'paymentMethod': 'UPI',
            'paymentStatus': 'PENDING_VERIFICATION',
            'total': 4091.0,
            'totalCases': 10,
            'createdAt': '2026-10-25T10:00:00Z',
          },
        ])),
    ...routes,
  });

  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(tokens),
      cartStorageProvider.overrideWithValue(cartStorage),
      screenshotPickerProvider.overrideWithValue(
        () async => XFile.fromData(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]), name: 'paid.png'),
      ),
      dioProvider.overrideWith((ref) => createApiClient(
            baseUrl: 'http://test',
            tokens: tokens,
            onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
            adapter: backend,
          )),
    ],
    child: const SmartRetailApp(),
  ));
  await tester.pumpAndSettle();
  return Harness(backend, cartStorage);
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adding from the product page fills the cart and the tab badge', (tester) async {
    final app = await pumpApp(tester);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thums Up 750ml PET'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byTooltip('One case more'));
    }
    await tester.pump();
    await tapText(tester, 'Add 10 cases to cart');

    expect(find.text('Added 10 cases of Thums Up 750ml PET'), findsOneWidget);
    expect(app.cart.lines.single.quantity, 10);
    // The message closes by itself, so it never covers the Cart's checkout button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Added 10 cases of Thums Up 750ml PET'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('10')), findsOneWidget);
  });

  testWidgets('cart shows server prices, applies a coupon and keeps the cart saved', (tester) async {
    final app = await pumpApp(tester, cart: [_cart]);
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('₹378/case'), findsOneWidget);
    expect(find.text('Bulk price'), findsOneWidget);
    expect(find.text('You save ₹420'), findsOneWidget);
    expect(find.text('Add ₹1,220 more for free delivery'), findsOneWidget);
    expect(find.text('Checkout · ₹4,280'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Coupon code'), 'save5');
    await tapText(tester, 'Apply');
    expect(find.text('You save ₹189'), findsOneWidget);
    expect(find.text('Checkout · ₹4,091'), findsOneWidget);
    expect(app.calls('POST', '/api/checkout/quote').last.data['couponCode'], 'SAVE5');

    // Going up to 11 cases re-prices on the server and is saved for next launch.
    await tester.tap(find.byTooltip('One case more of Thums Up 750ml PET'));
    await tester.pumpAndSettle();
    expect(app.cart.lines.single.quantity, 11);
    expect(app.calls('POST', '/api/checkout/quote').last.data['items'], [
      {'productId': 'id-thums-up-750', 'quantity': 11},
    ]);
  });

  testWidgets('checkout is blocked below the minimum order', (tester) async {
    await pumpApp(tester, cart: [_cart.withQuantity(2)]);
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('Minimum order is ₹1,000. Add ₹160 more.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Checkout · ₹1,340'));
    expect(button.onPressed, isNull);
  });

  testWidgets('places a UPI order with a new address and a screenshot', (tester) async {
    final app = await pumpApp(tester, cart: [_cart]);
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Coupon code'), 'SAVE5');
    await tapText(tester, 'Apply');
    await tapText(tester, 'Checkout · ₹4,091');

    // No saved address yet.
    expect(find.widgetWithText(FilledButton, 'Add a delivery address'), findsOneWidget);
    await tapText(tester, 'Add delivery address');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contact name'), 'Ravi Kumar');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile'), '9876501234');
    await tester.enterText(find.widgetWithText(TextFormField, 'Shop no., building, street'), '12 Main Road');
    await tester.enterText(find.widgetWithText(TextFormField, 'PIN code'), '500001');
    await tapText(tester, 'Save address');
    expect(find.text('Shop · Ravi Kumar'), findsOneWidget);

    await tapText(tester, 'UPI');
    expect(find.text('smartretail@upi'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Upload the UPI screenshot'), findsOneWidget);
    await tapText(tester, 'Choose screenshot');
    expect(find.text('Screenshot attached · tap to change'), findsOneWidget);

    await tapText(tester, 'Place order · ₹4,091');

    final placed = app.calls('POST', '/api/orders').single.data as Map<String, dynamic>;
    expect(placed, {
      'items': [
        {'productId': 'id-thums-up-750', 'quantity': 10},
      ],
      'couponCode': 'SAVE5',
      'addressId': 'addr-new',
      'paymentMethod': 'UPI',
      'paymentScreenshot': 'payments/abc.png',
      'notes': null,
      'expectedTotal': 4091.0,
    });
    expect(find.text('Order placed!'), findsOneWidget);
    expect(find.text('Order number SR1001'), findsOneWidget);
    expect(find.text('We will check your UPI payment and confirm the order.'), findsOneWidget);
    expect(app.cart.lines, isEmpty);

    await tapText(tester, 'My orders');
    expect(find.text('Order SR1001'), findsOneWidget);
    expect(find.textContaining('Payment being checked'), findsOneWidget);
  });

  testWidgets('shows the server reason when an order is refused and keeps the cart', (tester) async {
    final app = await pumpApp(
      tester,
      cart: [_cart],
      addresses: [_address],
      routes: {
        'POST /api/orders': (_) => const FakeResponse(409, {'detail': 'Only 3 cases of Thums Up 750ml PET are left.'}),
      },
    );
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Checkout · ₹4,280');

    expect(find.text('Shop · Ravi Kumar'), findsOneWidget);
    await tapText(tester, 'Place order · ₹4,280');

    expect(find.text('Only 3 cases of Thums Up 750ml PET are left.'), findsOneWidget);
    expect(app.cart.lines, hasLength(1));
    expect(app.calls('POST', '/api/orders').single.data['paymentMethod'], 'COD');
  });

  test('cart controller merges repeat adds and survives a restart', () async {
    final storage = InMemoryCartStorage([_cart]);
    final container = ProviderContainer(overrides: [cartStorageProvider.overrideWithValue(storage)]);
    addTearDown(container.dispose);

    container.read(cartProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(cartProvider).single.quantity, 10);
    expect(container.read(cartCountProvider), 10);

    container.read(cartProvider.notifier).setQuantity('id-thums-up-750', 0);
    expect(container.read(cartProvider), isEmpty);
    expect(storage.lines, isEmpty);
  });
}
