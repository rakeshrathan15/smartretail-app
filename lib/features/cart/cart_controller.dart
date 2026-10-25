import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../catalog/catalog_models.dart';

/// One product in the cart. Name, image and price are only for showing the cart quickly;
/// the server prices every order again from the product id and case count.
class CartLine {
  const CartLine({
    required this.productId,
    required this.slug,
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.unitVolumeMl,
    required this.unitsPerCase,
    required this.quantity,
  });

  final String productId;
  final String slug;
  final String name;
  final String? brand;
  final String? imageUrl;
  final int? unitVolumeMl;
  final int unitsPerCase;
  final int quantity;

  CartLine withQuantity(int quantity) => CartLine(
        productId: productId,
        slug: slug,
        name: name,
        brand: brand,
        imageUrl: imageUrl,
        unitVolumeMl: unitVolumeMl,
        unitsPerCase: unitsPerCase,
        quantity: quantity,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'slug': slug,
        'name': name,
        'brand': brand,
        'imageUrl': imageUrl,
        'unitVolumeMl': unitVolumeMl,
        'unitsPerCase': unitsPerCase,
        'quantity': quantity,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        productId: json['productId'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        imageUrl: json['imageUrl'] as String?,
        unitVolumeMl: json['unitVolumeMl'] as int?,
        unitsPerCase: json['unitsPerCase'] as int,
        quantity: json['quantity'] as int,
      );
}

/// Where the cart is kept between app launches.
abstract class CartStorage {
  Future<List<CartLine>> load();
  Future<void> save(List<CartLine> lines);
}

class PrefsCartStorage implements CartStorage {
  static const _key = 'cart.v1';

  @override
  Future<List<CartLine>> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>).map((e) => CartLine.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // A corrupt or old-format cart is dropped rather than crashing the app.
      return const [];
    }
  }

  @override
  Future<void> save(List<CartLine> lines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(lines.map((l) => l.toJson()).toList()));
  }
}

class InMemoryCartStorage implements CartStorage {
  InMemoryCartStorage([this.lines = const []]);

  List<CartLine> lines;

  @override
  Future<List<CartLine>> load() async => lines;

  @override
  Future<void> save(List<CartLine> lines) async => this.lines = lines;
}

final cartStorageProvider = Provider<CartStorage>((ref) => PrefsCartStorage());

final cartProvider = NotifierProvider<CartController, List<CartLine>>(CartController.new);

/// Total cases in the cart, for the badge on the Cart tab.
final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).fold(0, (sum, l) => sum + l.quantity));

class CartController extends Notifier<List<CartLine>> {
  static const maxCasesPerLine = 9999;

  bool _changedBeforeLoad = false;

  @override
  List<CartLine> build() {
    ref.read(cartStorageProvider).load().then((saved) {
      // Don't overwrite something the user added while the saved cart was loading.
      if (!_changedBeforeLoad && ref.mounted) state = saved;
    });
    return const [];
  }

  void add(ProductDetail product, int cases) {
    final existing = state.where((l) => l.productId == product.id).firstOrNull;
    if (existing != null) {
      setQuantity(product.id, existing.quantity + cases);
      return;
    }
    _update([
      ...state,
      CartLine(
        productId: product.id,
        slug: product.slug,
        name: product.name,
        brand: product.brand,
        imageUrl: product.images.where((i) => i.primary).firstOrNull?.url ?? product.images.firstOrNull?.url,
        unitVolumeMl: product.unitVolumeMl,
        unitsPerCase: product.unitsPerCase,
        quantity: cases.clamp(1, maxCasesPerLine),
      ),
    ]);
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) return remove(productId);
    _update([
      for (final line in state)
        line.productId == productId ? line.withQuantity(quantity.clamp(1, maxCasesPerLine)) : line,
    ]);
  }

  void remove(String productId) => _update(state.where((l) => l.productId != productId).toList());

  void clear() => _update(const []);

  void _update(List<CartLine> lines) {
    _changedBeforeLoad = true;
    state = lines;
    ref.read(cartStorageProvider).save(lines);
  }
}
