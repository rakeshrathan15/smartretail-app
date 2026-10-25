import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/catalog/catalog_models.dart';
import 'features/catalog/catalog_providers.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/home/home_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/product/product_detail_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/shell/main_shell.dart';

/// Where to send the user for their sign-in state, or null to stay. The page they asked for
/// is carried in `?from=` through the splash and login screens, so a link to a product still
/// opens that product after the saved session is checked or after signing in.
String? authRedirect({required bool loading, required bool signedIn, required Uri uri}) {
  final location = uri.path;
  final from = _safeFrom(uri.queryParameters['from']);
  if (loading) {
    return location == '/splash' ? null : '/splash?from=${Uri.encodeComponent(uri.toString())}';
  }

  final onAuthPage = location == '/login' || location == '/register';
  if (!signedIn) {
    if (onAuthPage) return null;
    final target = location == '/splash' ? from : _safeFrom(uri.toString());
    return target == null || target == '/home' ? '/login' : '/login?from=${Uri.encodeComponent(target)}';
  }
  if (onAuthPage || location == '/splash') return from ?? '/home';
  return null;
}

/// Only in-app paths, never another site or an auth screen.
String? _safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) return null;
  if (from.startsWith('/splash') || from.startsWith('/login') || from.startsWith('/register')) return null;
  return from;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever the user signs in or out.
  final authChanged = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => authChanged.value++);
  ref.onDispose(authChanged.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authChanged,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return authRedirect(loading: auth.isLoading, signedIn: auth.value != null, uri: state.uri);
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/product/:slug',
        builder: (_, state) => ProductDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: '/order-placed/:id',
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!, justPlaced: true),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/shop',
              builder: (_, state) {
                final params = state.uri.queryParameters;
                return ShopScreen(
                  initialQuery: ShopQuery(
                    category: params['category'],
                    sort: ProductSort.fromApi(params['sort']),
                    dealsOnly: params['deals'] == '1',
                  ),
                  focusSearch: params['search'] == '1',
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
