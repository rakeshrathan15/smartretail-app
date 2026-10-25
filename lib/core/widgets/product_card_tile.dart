import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/catalog/catalog_models.dart';
import '../format.dart';
import 'product_thumb.dart';

/// Product tile for grids and horizontal lists. Opens the product page on tap.
class ProductCardTile extends StatelessWidget {
  const ProductCardTile({super.key, required this.product});

  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discount = product.discountPercent;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/product/${product.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The photo takes whatever height the text below leaves, so the tile never overflows.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductThumb(imageUrl: product.imageUrl, label: product.brand ?? product.name),
                  if (discount != null)
                    Positioned(top: 8, left: 8, child: _Pill(text: '$discount% OFF', color: theme.colorScheme.secondary)),
                  if (product.badge != null)
                    Positioned(top: 8, right: 8, child: _Pill(text: product.badge!, color: Colors.black87)),
                  if (!product.inStock)
                    const ColoredBox(
                      color: Color(0x99FFFFFF),
                      child: Center(child: _Pill(text: 'Out of stock', color: Colors.black87)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand != null)
                    Text(
                      product.brand!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, letterSpacing: 0.6),
                    ),
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(packSize(product.unitVolumeMl, product.unitsPerCase),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 6,
                    children: [
                      Text('${formatRupees(product.price)}/case',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      if (product.originalPrice != null && discount != null)
                        Text(
                          formatRupees(product.originalPrice!),
                          style: theme.textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough),
                        ),
                    ],
                  ),
                  if (product.hasBulkDiscount)
                    Text(
                      'as low as ${formatRupees(product.lowestPrice)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
