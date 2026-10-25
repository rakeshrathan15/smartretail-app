import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/home_leading.dart';
import '../../core/widgets/product_thumb.dart';
import '../cart/cart_controller.dart';
import '../catalog/catalog_models.dart';
import '../catalog/catalog_providers.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(slug));
    return product.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: ErrorRetry(message: '$e', onRetry: () => ref.invalidate(productDetailProvider(slug)))),
      ),
      data: (p) => _ProductView(product: p),
    );
  }
}

class _ProductView extends ConsumerStatefulWidget {
  const _ProductView({required this.product});

  final ProductDetail product;

  @override
  ConsumerState<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends ConsumerState<_ProductView> {
  int _cases = 1;

  ProductDetail get p => widget.product;

  void _setCases(int value) => setState(() => _cases = value.clamp(1, 9999));

  void _addToCart() {
    ref.read(cartProvider.notifier).add(p, _cases);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Added $_cases ${_cases == 1 ? 'case' : 'cases'} of ${p.name}'),
      // A SnackBar with an action stays until dismissed by default; it would hide the Cart's checkout button.
      persist: false,
      action: SnackBarAction(label: 'View cart', onPressed: () => context.go('/cart')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitPrice = p.pricePerCaseFor(_cases);
    final total = unitPrice * _cases;
    final saving = (p.price - unitPrice) * _cases;
    final discount = p.discountPercent;

    return Scaffold(
      appBar: AppBar(leading: backOrHome(context), title: Text(p.brand ?? 'Product')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AspectRatio(aspectRatio: 1.5, child: _Gallery(product: p)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.category != null)
                  Text(p.category!.name.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                Text(p.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  [packSize(p.unitVolumeMl, p.unitsPerCase), ?p.flavor].join(' · '),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text('${formatRupees(p.price)}/case',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    if (discount != null) ...[
                      Text(formatRupees(p.originalPrice!),
                          style: theme.textTheme.bodyMedium?.copyWith(decoration: TextDecoration.lineThrough)),
                      Text('$discount% off',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  p.inStock ? 'In stock' : 'Out of stock',
                  style: TextStyle(color: p.inStock ? Colors.green.shade700 : theme.colorScheme.error),
                ),
                if (p.slabs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Bulk prices', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _SlabTable(product: p, cases: _cases),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Cases', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    IconButton.outlined(
                      onPressed: _cases > 1 ? () => _setCases(_cases - 1) : null,
                      icon: const Icon(Icons.remove),
                      tooltip: 'One case less',
                    ),
                    SizedBox(
                      width: 56,
                      child: Text('$_cases',
                          key: const Key('case-count'), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                    ),
                    IconButton.outlined(
                      onPressed: () => _setCases(_cases + 1),
                      icon: const Icon(Icons.add),
                      tooltip: 'One case more',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _Line(label: 'Price per case', value: formatRupees(unitPrice)),
                        _Line(label: 'Total ($_cases × ${p.unitsPerCase} units)', value: formatRupees(total), bold: true),
                        if (saving > 0)
                          _Line(
                            label: 'Bulk saving',
                            value: formatRupees(saving),
                            color: Colors.green.shade700,
                          ),
                      ],
                    ),
                  ),
                ),
                if (p.description != null) ...[
                  const SizedBox(height: 20),
                  Text('About', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(p.description!),
                ],
                if (p.ingredients != null) ...[
                  const SizedBox(height: 16),
                  Text('Ingredients', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(p.ingredients!),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: p.inStock ? _addToCart : null,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(p.inStock ? 'Add $_cases ${_cases == 1 ? 'case' : 'cases'} to cart' : 'Out of stock'),
          ),
        ),
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.product});

  final ProductDetail product;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final label = p.brand ?? p.name;
    if (p.images.isEmpty) return ProductThumb(imageUrl: null, label: label, iconSize: 64);

    return Stack(
      children: [
        PageView(
          onPageChanged: (i) => setState(() => _index = i),
          children: [for (final image in p.images) ProductThumb(imageUrl: image.url, label: label, iconSize: 64)],
        ),
        if (p.images.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < p.images.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index ? Colors.white : Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Rows like "1–9 cases ₹420", "10–24 cases ₹378", "25+ cases ₹357"; the row that applies is highlighted.
class _SlabTable extends StatelessWidget {
  const _SlabTable({required this.product, required this.cases});

  final ProductDetail product;
  final int cases;

  @override
  Widget build(BuildContext context) {
    final rows = <(int, int?, double)>[];
    final slabs = product.slabs;
    if (slabs.first.minQty > 1) rows.add((1, slabs.first.minQty - 1, product.price));
    for (var i = 0; i < slabs.length; i++) {
      final next = i + 1 < slabs.length ? slabs[i + 1].minQty - 1 : null;
      rows.add((slabs[i].minQty, slabs[i].maxQty ?? next, slabs[i].pricePerCase));
    }
    final applied = product.pricePerCaseFor(cases);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (final (min, max, price) in rows)
            Builder(builder: (context) {
              final active = cases >= min && (max == null || cases <= max) && price == applied;
              return Container(
                color: active ? theme.colorScheme.primaryContainer : null,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(max == null ? '$min+ cases' : '$min–$max cases')),
                    Text('${formatRupees(price)}/case',
                        style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
