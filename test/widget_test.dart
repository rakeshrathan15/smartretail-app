import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_retail_app/core/api_client.dart';
import 'package:smart_retail_app/core/providers.dart';
import 'package:smart_retail_app/core/token_storage.dart';
import 'package:smart_retail_app/features/auth/auth_controller.dart';
import 'package:smart_retail_app/features/cart/cart_controller.dart';
import 'package:smart_retail_app/main.dart';

import 'fake_backend.dart';

Widget appWith(FakeBackend backend, TokenStorage tokens) {
  return ProviderScope(
    // Fail fast in tests instead of retrying failed requests on a timer.
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
  );
}

void main() {
  testWidgets('shows the login screen when there is no saved session', (tester) async {
    await tester.pumpWidget(appWith(FakeBackend({}), InMemoryTokenStorage()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter your email or mobile'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('shows the server error when the password is wrong', (tester) async {
    final backend = FakeBackend({
      'POST /api/auth/login': (_) => const FakeResponse(401, {'detail': 'Invalid email/mobile or password'}),
    });
    await tester.pumpWidget(appWith(backend, InMemoryTokenStorage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email/mobile or password'), findsOneWidget);
  });

  testWidgets('signs in, shows the profile tab, and signs out', (tester) async {
    final tokens = InMemoryTokenStorage();
    final backend = FakeBackend({
      ...catalogRoutes(),
      'POST /api/auth/login': (_) => FakeResponse(200, authJson()),
      'POST /api/auth/logout': (_) => const FakeResponse(204),
    });
    await tester.pumpWidget(appWith(backend, tokens));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(await tokens.readRefreshToken(), 'refresh-1');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('+91 9876543210'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(await tokens.readRefreshToken(), isNull);
  });

  testWidgets('restores a saved session on startup', (tester) async {
    final tokens = InMemoryTokenStorage();
    await tokens.save(accessToken: 'access-1', refreshToken: 'refresh-1');
    final backend = FakeBackend({
      ...catalogRoutes(),
      'GET /api/me': (_) => FakeResponse(200, userJson(fullName: 'Saved User')),
    });

    await tester.pumpWidget(appWith(backend, tokens));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Saved User'), findsOneWidget);
  });
}
