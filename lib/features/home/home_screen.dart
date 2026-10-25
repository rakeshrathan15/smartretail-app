import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/product_card_tile.dart';
import '../catalog/catalog_models.dart';
import '../catalog/catalog_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(storeInfoProvider);
    ref.invalidate(bannersProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(dealsProvider);
    ref.invalidate(newArrivalsProvider);
    await ref.read(dealsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _StoreHeader()),
            const SliverToBoxAdapter(child: _BannerCarousel()),
            const SliverToBoxAdapter(child: _CategoryStrip()),
            const SliverToBoxAdapter(child: _TrustBadges()),
            SliverToBoxAdapter(
              child: _ProductRail(
                title: 'Special Deals',
                icon: Icons.local_offer_outlined,
                provider: dealsProvider,
                viewAllLocation: '/shop?deals=1',
              ),
            ),
            SliverToBoxAdapter(
              child: _ProductRail(
                title: 'New Arrivals',
                icon: Icons.fiber_new_outlined,
                provider: newArrivalsProvider,
                viewAllLocation: '/shop?sort=NEWEST',
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _StoreHeader extends ConsumerWidget {
  const _StoreHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeInfoProvider).value;
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      color: AppTheme.brandNavy,
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store?.name ?? "S'Mart Retail",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (store != null && store.address.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(store.address,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (store != null) _OpenChip(isOpen: store.isOpen),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.go('/shop?search=1'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.black54),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Search colas, juices, water…',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.black54)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenChip extends StatelessWidget {
  const _OpenChip({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? Colors.greenAccent.shade400 : Colors.redAccent.shade100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(isOpen ? 'Open' : 'Closed', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BannerCarousel extends ConsumerStatefulWidget {
  const _BannerCarousel();

  @override
  ConsumerState<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<_BannerCarousel> {
  static const _gradients = [
    [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
    [Color(0xFFB91C1C), Color(0xFFF97316)],
    [Color(0xFF047857), Color(0xFF10B981)],
  ];

  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay(int count) {
    if (_timer != null || count < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      _controller.animateToPage((_page + 1) % count, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(bannersProvider);
    final items = banners.value ?? const <BannerItem>[];
    if (items.isEmpty) return const SizedBox(height: 8);
    _startAutoPlay(items.length);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            child: PageView.builder(
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _BannerSlide(banner: items[i], colors: _gradients[i % _gradients.length]),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppTheme.brandNavy : Colors.black26,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerSlide extends ConsumerWidget {
  const _BannerSlide({required this.banner, required this.colors});

  final BannerItem banner;
  final List<Color> colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = banner.link;
    final image = banner.imageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: colors))),
            if (image != null)
              Image.network(ref.watch(mediaUrlProvider)(image), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
            if (image != null) const DecoratedBox(decoration: BoxDecoration(color: Color(0x66000000))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(banner.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  if (banner.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(banner.subtitle!,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                  ],
                  if (banner.ctaText != null && link != null && link.startsWith('/')) ...[
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        backgroundColor: Colors.white,
                        foregroundColor: colors.first,
                      ),
                      onPressed: () => context.go(link),
                      child: Text(banner.ctaText!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip();

  static const _icons = {
    'colas': Icons.local_drink,
    'juices': Icons.emoji_food_beverage,
    'energy-drinks': Icons.bolt,
    'packaged-water': Icons.water_drop,
    'sparkling-lime': Icons.bubble_chart,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return categories.when(
      loading: () => const SizedBox(height: 124),
      error: (e, _) => ErrorRetry(message: '$e', onRetry: () => ref.invalidate(categoriesProvider)),
      data: (items) => SizedBox(
        height: 124,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final category = items[i];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go('/shop?category=${category.slug}'),
              child: SizedBox(
                width: 72,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(_icons[category.slug] ?? Icons.category_outlined, color: AppTheme.brandNavy),
                    ),
                    const SizedBox(height: 6),
                    Text(category.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrustBadges extends StatelessWidget {
  const _TrustBadges();

  static const _badges = [
    (Icons.verified_outlined, 'FSSAI\nCertified'),
    (Icons.local_shipping_outlined, 'Bulk\nDelivery'),
    (Icons.sell_outlined, 'Best Slab\nPrices'),
    (Icons.schedule_outlined, 'Same-Day\nDispatch'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          for (final (icon, label) in _badges)
            Expanded(
              child: Column(
                children: [
                  Icon(icon, color: AppTheme.brandRed),
                  const SizedBox(height: 4),
                  Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductRail extends ConsumerWidget {
  const _ProductRail({
    required this.title,
    required this.icon,
    required this.provider,
    required this.viewAllLocation,
  });

  final String title;
  final IconData icon;
  final FutureProvider<List<ProductCard>> provider;
  final String viewAllLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(provider);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.brandRed),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                TextButton(onPressed: () => context.go(viewAllLocation), child: const Text('View all')),
              ],
            ),
          ),
          products.when(
            loading: () => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorRetry(message: '$e', onRetry: () => ref.invalidate(provider)),
            data: (items) => items.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('Nothing here yet.'))
                : SizedBox(
                    height: 270,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(width: 160, child: ProductCardTile(product: items[i])),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
