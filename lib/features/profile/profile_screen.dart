import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import 'delivery_route_repository.dart';
import 'shop_profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: () => ref.read(authControllerProvider.notifier).refreshUser(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          (user.fullName?.isNotEmpty ?? false) ? user.fullName![0].toUpperCase() : '?',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName ?? 'Shop owner', style: theme.textTheme.titleLarge),
                            Text(user.roles.join(', '), style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!user.shopProfileComplete)
                    Card(
                      color: theme.colorScheme.secondaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.store_mall_directory_outlined),
                        title: const Text('Complete your shop profile'),
                        subtitle: const Text('Shop name, GSTIN and location are needed for delivery.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/shop-profile'),
                      ),
                    )
                  else
                    const _ShopCard(),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.phone_outlined),
                          title: const Text('Mobile'),
                          subtitle: Text(user.phone == null ? 'Not added' : '+91 ${user.phone}'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.email_outlined),
                          title: const Text('Email'),
                          subtitle: Text(user.email ?? 'Not added'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ShopCard extends ConsumerWidget {
  const _ShopCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProfileProvider).value;
    final route = ref.watch(deliveryRouteProvider).whenOrNull(data: (route) => route);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.storefront_outlined),
        title: Text(shop?.shopName ?? 'Shop'),
        subtitle: Text([
          if (shop?.address != null) shop!.address!,
          if (shop?.gstNumber != null) 'GSTIN ${shop!.gstNumber}',
          if (route != null) ..._routeLines(route),
        ].join('\n')),
        isThreeLine: shop?.gstNumber != null || route != null,
        trailing: const Text('Edit'),
        onTap: () => context.push('/shop-profile'),
      ),
    );
  }

  static List<String> _routeLines(MyDeliveryRoute route) {
    if (!route.assigned) return const ['Not on a delivery route yet'];
    final next = route.nextDeliveryLabel;
    return [
      'Delivery route: ${route.name}${route.days.isEmpty ? '' : ' (${route.daysLabel})'}',
      if (next != null) 'Order today, delivered $next',
    ];
  }
}
