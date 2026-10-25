import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_retail_app/core/api_client.dart';
import 'package:smart_retail_app/core/format.dart';
import 'package:smart_retail_app/core/providers.dart';
import 'package:smart_retail_app/core/token_storage.dart';
import 'package:smart_retail_app/features/auth/auth_controller.dart';
import 'package:smart_retail_app/features/cart/cart_controller.dart';
import 'package:smart_retail_app/features/catalog/catalog_models.dart';
import 'package:smart_retail_app/main.dart';

import 'fake_backend.dart';

Future<FakeBackend> pumpSignedInApp(WidgetTester tester) async {
  // A phone-sized screen, so the home sections lay out as on a device.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final tokens = InMemoryTokenStorage();
  await tokens.save(accessToken: 'access-1', refreshToken: 'refresh-1');
  final backend = FakeBackend({
    ...catalogRoutes(),
    'GET /api/me': (_) => FakeResponse(200, userJson()),
  });
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(tokens),
      cartStorageProvider.overrideWithValue(InMemoryCartStorage()),
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
  return backend;
}

ProductDetail detailWithSlabs() => ProductDetail.fromJson({
      ...productJson('cola', 'Cola', original: 480),
      'flavor': null,
      'category': null,
      'weight': null,
      'description': null,
      'ingredients': null,
      'images': <dynamic>[],
      'slabs': [
        {'minQty': 10, 'maxQty': 24, 'pricePerCase': 378},
        {'minQty': 25, 'maxQty': null, 'pricePerCase': 357},
      ],
    });

void main() {
  group('pricing and formatting', () {
    test('applies the highest slab reached, like the backend', () {
      final cola = detailWithSlabs();
      expect(cola.pricePerCaseFor(1), 420);
      expect(cola.pricePerCaseFor(9), 420);
      expect(cola.pricePerCaseFor(10), 378);
      expect(cola.pricePerCaseFor(25), 357);
      expect(cola.pricePerCaseFor(300), 357);
      expect(cola.discountPercent, 13);
      expect(cola.hasBulkDiscount, isTrue);
    });

    test('formats rupees with Indian grouping and pack sizes', () {
      expect(formatRupees(420), '₹420');
      expect(formatRupees(1440), '₹1,440');
      expect(formatRupees(150000), '₹1,50,000');
      expect(formatRupees(378.5), '₹378.50');
      expect(packSize(750, 12), '750ml × 12/case');
      expect(packSize(1000, 12), '1L × 12/case');
      expect(packSize(null, 6), '6/case');
    });
  });

  testWidgets('home shows store, banner, categories and deals', (tester) async {
    final backend = await pumpSignedInApp(tester);

    expect(find.text("S'Mart Retail"), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Bulk case pricing'), findsOneWidget);
    expect(find.text('Juices'), findsOneWidget);
    expect(find.text('Special Deals'), findsOneWidget);
    expect(find.text('Thums Up 750ml PET'), findsWidgets);
    expect(find.text('13% OFF'), findsWidgets);
    expect(find.text('as low as ₹357'), findsWidgets);
    expect(
      backend.requests.where((r) => r.path == '/api/products').map((r) => r.queryParameters['deals']),
      contains(true),
    );
  });

  testWidgets('tapping a home category opens the shop filtered to it', (tester) async {
    final backend = await pumpSignedInApp(tester);

    await tester.tap(find.text('Juices'));
    await tester.pumpAndSettle();

    expect(find.text('Maaza Mango 600ml'), findsOneWidget);
    expect(find.text('Thums Up 750ml PET'), findsNothing);
    expect(find.text('1 products'), findsOneWidget);
    expect(backend.requests.last.queryParameters['category'], 'juices');
  });

  testWidgets('shop sorts and filters, and the product page applies slab prices', (tester) async {
    final backend = await pumpSignedInApp(tester);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(find.text('2 products'), findsOneWidget);

    await tester.ensureVisible(find.text('Price: High'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price: High'));
    await tester.pumpAndSettle();
    expect(backend.requests.last.queryParameters['sort'], 'PRICE_DESC');

    await tester.tap(find.text('Thums Up 750ml PET'));
    await tester.pumpAndSettle();

    expect(find.text('Bulk prices'), findsOneWidget);
    expect(find.text('1–9 cases'), findsOneWidget);
    expect(find.text('10–24 cases'), findsOneWidget);
    expect(find.text('25+ cases'), findsOneWidget);

    // Nine more cases reaches the 10-case slab.
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byTooltip('One case more'));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('case-count')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('case-count'))).data, '10');
    expect(find.text('₹3,780'), findsOneWidget); // 10 × ₹378
    expect(find.text('₹420'), findsOneWidget); // saving: 10 × (420 − 378)

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsWidgets);
  });
}
