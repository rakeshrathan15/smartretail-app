/// Catalog types mirroring the backend's CatalogDtos. Prices are rupees per case.
library;

double _money(Object? value) => (value as num).toDouble();

double? _moneyOrNull(Object? value) => value == null ? null : (value as num).toDouble();

class Category {
  const Category({required this.id, required this.name, required this.slug, this.imageUrl});

  final String id;
  final String name;
  final String slug;
  final String? imageUrl;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        imageUrl: json['imageUrl'] as String?,
      );
}

/// Shared by list cards and the detail page.
mixin ProductPricing {
  double get price;
  double? get originalPrice;
  double get lowestPrice;

  /// Whole-number percentage off the original price, or null when there is no discount.
  int? get discountPercent {
    final original = originalPrice;
    if (original == null || original <= price) return null;
    return ((original - price) / original * 100).round();
  }

  bool get hasBulkDiscount => lowestPrice < price;
}

class ProductCard with ProductPricing {
  const ProductCard({
    required this.id,
    required this.slug,
    required this.name,
    required this.brand,
    required this.unitVolumeMl,
    required this.unitsPerCase,
    required this.price,
    required this.originalPrice,
    required this.lowestPrice,
    required this.imageUrl,
    required this.inStock,
    required this.badge,
  });

  final String id;
  final String slug;
  final String name;
  final String? brand;
  final int? unitVolumeMl;
  final int unitsPerCase;
  @override
  final double price;
  @override
  final double? originalPrice;
  @override
  final double lowestPrice;
  final String? imageUrl;
  final bool inStock;
  final String? badge;

  factory ProductCard.fromJson(Map<String, dynamic> json) => ProductCard(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        unitVolumeMl: json['unitVolumeMl'] as int?,
        unitsPerCase: json['unitsPerCase'] as int,
        price: _money(json['price']),
        originalPrice: _moneyOrNull(json['originalPrice']),
        lowestPrice: _money(json['lowestPrice']),
        imageUrl: json['imageUrl'] as String?,
        inStock: json['inStock'] as bool,
        badge: json['badge'] as String?,
      );
}

class PriceSlab {
  const PriceSlab({required this.minQty, required this.maxQty, required this.pricePerCase});

  final int minQty;
  final int? maxQty;
  final double pricePerCase;

  factory PriceSlab.fromJson(Map<String, dynamic> json) => PriceSlab(
        minQty: json['minQty'] as int,
        maxQty: json['maxQty'] as int?,
        pricePerCase: _money(json['pricePerCase']),
      );
}

class ProductImageInfo {
  const ProductImageInfo({required this.id, required this.url, required this.primary});

  final String id;
  final String url;
  final bool primary;

  factory ProductImageInfo.fromJson(Map<String, dynamic> json) => ProductImageInfo(
        id: json['id'] as String,
        url: json['url'] as String,
        primary: json['primary'] as bool,
      );
}

class ProductDetail with ProductPricing {
  const ProductDetail({
    required this.id,
    required this.slug,
    required this.name,
    required this.brand,
    required this.flavor,
    required this.category,
    required this.unitVolumeMl,
    required this.unitsPerCase,
    required this.price,
    required this.originalPrice,
    required this.lowestPrice,
    required this.inStock,
    required this.badge,
    required this.description,
    required this.ingredients,
    required this.images,
    required this.slabs,
  });

  final String id;
  final String slug;
  final String name;
  final String? brand;
  final String? flavor;
  final Category? category;
  final int? unitVolumeMl;
  final int unitsPerCase;
  @override
  final double price;
  @override
  final double? originalPrice;
  @override
  final double lowestPrice;
  final bool inStock;
  final String? badge;
  final String? description;
  final String? ingredients;
  final List<ProductImageInfo> images;

  /// Sorted by minQty, as the backend returns them.
  final List<PriceSlab> slabs;

  /// Same rule as the backend: the slab with the highest minQty not above [cases].
  double pricePerCaseFor(int cases) {
    PriceSlab? best;
    for (final slab in slabs) {
      if (slab.minQty <= cases && (best == null || slab.minQty > best.minQty)) best = slab;
    }
    return best?.pricePerCase ?? price;
  }

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        flavor: json['flavor'] as String?,
        category: json['category'] == null ? null : Category.fromJson(json['category'] as Map<String, dynamic>),
        unitVolumeMl: json['unitVolumeMl'] as int?,
        unitsPerCase: json['unitsPerCase'] as int,
        price: _money(json['price']),
        originalPrice: _moneyOrNull(json['originalPrice']),
        lowestPrice: _money(json['lowestPrice']),
        inStock: json['inStock'] as bool,
        badge: json['badge'] as String?,
        description: json['description'] as String?,
        ingredients: json['ingredients'] as String?,
        images: (json['images'] as List<dynamic>)
            .map((e) => ProductImageInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        slabs: (json['slabs'] as List<dynamic>).map((e) => PriceSlab.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class BannerItem {
  const BannerItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.ctaText,
    this.link,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? ctaText;

  /// An in-app path such as "/shop?category=colas".
  final String? link;
  final String? imageUrl;

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        ctaText: json['ctaText'] as String?,
        link: json['link'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );
}

class PageResult<T> {
  const PageResult({required this.items, required this.page, required this.totalItems, required this.totalPages});

  final List<T> items;
  final int page;
  final int totalItems;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;

  factory PageResult.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) item) => PageResult(
        items: (json['items'] as List<dynamic>).map((e) => item(e as Map<String, dynamic>)).toList(),
        page: json['page'] as int,
        totalItems: json['totalItems'] as int,
        totalPages: json['totalPages'] as int,
      );
}

/// The public store settings the storefront shows.
class StoreInfo {
  const StoreInfo({required this.name, required this.address, required this.isOpen, required this.phone});

  final String name;
  final String address;
  final bool isOpen;
  final String phone;

  factory StoreInfo.fromSettings(Map<String, dynamic> settings) => StoreInfo(
        name: (settings['store_name'] as String?)?.trim().isNotEmpty == true
            ? settings['store_name'] as String
            : "S'Mart Retail",
        address: settings['store_address'] as String? ?? '',
        isOpen: settings['store_open'] != 'false',
        phone: settings['store_phone'] as String? ?? '',
      );
}

enum ProductSort {
  popular('POPULAR', 'Popular'),
  priceAsc('PRICE_ASC', 'Price: Low'),
  priceDesc('PRICE_DESC', 'Price: High'),
  newest('NEWEST', 'Newest');

  const ProductSort(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ProductSort fromApi(String? value) =>
      ProductSort.values.firstWhere((s) => s.apiValue == value, orElse: () => ProductSort.popular);
}
