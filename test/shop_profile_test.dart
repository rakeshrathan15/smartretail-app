import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_retail_app/core/api_client.dart';
import 'package:smart_retail_app/core/providers.dart';
import 'package:smart_retail_app/core/token_storage.dart';
import 'package:smart_retail_app/features/auth/auth_controller.dart';
import 'package:smart_retail_app/features/cart/cart_controller.dart';
import 'package:smart_retail_app/features/profile/shop_profile_repository.dart';
import 'package:smart_retail_app/main.dart';

import 'fake_backend.dart';

const _empty = {
  'shopName': null,
  'ownerName': 'Ravi Kumar',
  'phone': '9876543210',
  'gstNumber': null,
  'address': null,
  'city': null,
  'state': null,
  'pincode': null,
  'lat': null,
  'lng': null,
  'complete': false,
};

Future<FakeBackend> pumpApp(WidgetTester tester, {required Map<String, FakeHandler> routes, TokenStorage? tokens}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final storage = tokens ?? InMemoryTokenStorage();
  final backend = FakeBackend({...catalogRoutes(), ...routes});
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      cartStorageProvider.overrideWithValue(InMemoryCartStorage()),
      mapTilesEnabledProvider.overrideWithValue(false),
      currentLocationProvider.overrideWithValue(() async => const LatLng(17.4374, 78.4482)),
      dioProvider.overrideWith((ref) => createApiClient(
            baseUrl: 'http://test',
            tokens: storage,
            onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
            adapter: backend,
          )),
    ],
    child: const SmartRetailApp(),
  ));
  await tester.pumpAndSettle();
  return backend;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapButton(WidgetTester tester, String label) async {
  // Typing scrolls the focused field into view; let that finish before scrolling to the button.
  await tester.pumpAndSettle();
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new account is asked for its shop and location, then goes home', (tester) async {
    Map<String, dynamic>? saved;
    var complete = false;
    await pumpApp(tester, routes: {
      'POST /api/auth/register': (_) => FakeResponse(201, authJson()),
      'GET /api/me/shop-profile': (_) => const FakeResponse(200, _empty),
      'PUT /api/me/shop-profile': (req) {
        saved = req.data as Map<String, dynamic>;
        complete = true;
        return FakeResponse(200, {...saved!, 'complete': true});
      },
      'GET /api/me': (_) => FakeResponse(200, {...userJson(), 'shopProfileComplete': complete}),
    });

    await tapText(tester, 'New shop? Create an account');
    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Ravi Kumar');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), '9876543210');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Complete your shop profile'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Owner name *')).controller!.text, 'Ravi Kumar');

    // No pin yet: saving points at the map.
    await tester.enterText(find.widgetWithText(TextFormField, 'Shop name *'), 'Lakshmi Kirana');
    await tester.enterText(find.widgetWithText(TextFormField, 'Address / landmark *'), '4-1-20, Main Road, Ameerpet');
    await tester.enterText(find.widgetWithText(TextFormField, 'PIN code *'), '500016');
    await tapButton(tester, 'Save shop profile');
    expect(find.text('Place the pin on your shop'), findsOneWidget);
    expect(saved, isNull);

    await tapText(tester, 'Use my current location');
    expect(find.text('17.43740, 78.44820'), findsOneWidget);
    await tapButton(tester, 'Save shop profile');

    expect(saved, {
      'shopName': 'Lakshmi Kirana',
      'ownerName': 'Ravi Kumar',
      'phone': '9876543210',
      'gstNumber': null,
      'address': '4-1-20, Main Road, Ameerpet',
      'city': 'Hyderabad',
      'state': 'Telangana',
      'pincode': '500016',
      'lat': 17.4374,
      'lng': 78.4482,
    });
    // Home now, with the bottom menu.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Special Deals'), findsOneWidget);
  });

  testWidgets('an existing shop edits its profile from the Profile tab', (tester) async {
    final tokens = InMemoryTokenStorage();
    await tokens.save(accessToken: 'access-1', refreshToken: 'refresh-1');
    Map<String, dynamic>? saved;
    final profile = {
      ..._empty,
      'shopName': 'Lakshmi Kirana',
      'address': '4-1-20, Main Road',
      'city': 'Hyderabad',
      'pincode': '500016',
      'gstNumber': '36ABCDE1234F1Z5',
      'lat': 17.4374,
      'lng': 78.4482,
      'complete': true,
    };
    await pumpApp(tester, tokens: tokens, routes: {
      'GET /api/me': (_) => FakeResponse(200, {...userJson(), 'shopProfileComplete': true}),
      'GET /api/me/shop-profile': (_) => FakeResponse(200, profile),
      'PUT /api/me/shop-profile': (req) {
        saved = req.data as Map<String, dynamic>;
        return FakeResponse(200, {...saved!, 'complete': true});
      },
    });

    await tapText(tester, 'Profile');
    expect(find.text('Lakshmi Kirana'), findsOneWidget);
    await tapText(tester, 'Edit');
    expect(find.text('Shop profile'), findsOneWidget);
    expect(find.text('17.43740, 78.44820'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'GSTIN (optional)'), 'BAD');
    await tapButton(tester, 'Save changes');
    expect(find.text('A GSTIN has 15 characters, e.g. 36ABCDE1234F1Z5'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'GSTIN (optional)'), '36abcde1234f1z5');
    await tapButton(tester, 'Save changes');
    expect(saved?['gstNumber'], '36ABCDE1234F1Z5');
    expect(find.text('Saved Lakshmi Kirana'), findsOneWidget);
  });
}
