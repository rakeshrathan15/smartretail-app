# S'Mart Retail App (Flutter)

Customer app for ordering beverages by the case. Talks to `../smart-retail-backend`.

Flutter 3.47 · Riverpod 3 · go_router · Dio · flutter_secure_storage · shared_preferences · image_picker

## Run

Start the backend first (`cd ../smart-retail-backend && ./gradlew bootRun`), then:

```bash
flutter run                                   # Android emulator → http://10.0.2.2:8080
flutter run -d chrome --web-port 8081         # web; port 8081 is allowed by backend CORS in dev
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080   # physical phone: your Mac's Wi-Fi IP
```

Dev admin login: see `../smart-retail-backend/src/main/resources/application-dev.yml`.

```bash
flutter analyze
flutter test
```

## Layout

```
lib/
├── main.dart              ProviderScope + MaterialApp.router
├── router.dart            routes, sign-in redirect, bottom-nav branches
├── core/
│   ├── config.dart        API base URL per platform
│   ├── api_client.dart    Dio + bearer token + automatic refresh on 401
│   ├── api_exception.dart reads backend problem-detail errors
│   ├── token_storage.dart secure storage (Keychain / encrypted prefs)
│   ├── providers.dart     shared Riverpod providers
│   └── theme.dart
└── features/
    ├── auth/              login, register, AuthController (signed-in user)
    ├── catalog/           models, repository and providers for products, categories, banners
    ├── home/ shop/ product/  storefront screens
    ├── cart/              cart (saved on the device), cart screen, order summary
    ├── checkout/          quote, addresses, payment (COD / UPI screenshot / credit), place order
    ├── orders/            my orders, order detail and "order placed" screen
    ├── shell/             bottom navigation with the cart badge
    └── profile/           profile + sign out
```

The cart stores only products and case counts. Prices shown in the cart and at checkout come from the
server's quote (`POST /api/checkout/quote`), and the order is sent with the total the user saw, so a
price change is caught instead of charged.
