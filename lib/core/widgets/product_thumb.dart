import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// A product photo, or a coloured placeholder with the brand name when there is none.
class ProductThumb extends ConsumerWidget {
  const ProductThumb({super.key, required this.imageUrl, required this.label, this.iconSize = 40});

  final String? imageUrl;

  /// Shown on the placeholder; usually the brand.
  final String label;
  final double iconSize;

  static const _palette = [
    Color(0xFF1E3A8A),
    Color(0xFFB91C1C),
    Color(0xFF047857),
    Color(0xFFB45309),
    Color(0xFF6D28D9),
    Color(0xFF0E7490),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = imageUrl;
    if (url == null) return _placeholder();
    return Image.network(
      ref.watch(mediaUrlProvider)(url),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    final color = _palette[label.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_drink_outlined, color: Colors.white70, size: iconSize),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
