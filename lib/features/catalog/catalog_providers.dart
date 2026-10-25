import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) => ref.watch(catalogRepositoryProvider).categories());

final bannersProvider = FutureProvider<List<BannerItem>>((ref) => ref.watch(catalogRepositoryProvider).banners());

final storeInfoProvider = FutureProvider<StoreInfo>((ref) => ref.watch(catalogRepositoryProvider).storeInfo());

final dealsProvider = FutureProvider<List<ProductCard>>((ref) async =>
    (await ref.watch(catalogRepositoryProvider).products(dealsOnly: true, size: 10)).items);

final newArrivalsProvider = FutureProvider<List<ProductCard>>((ref) async =>
    (await ref.watch(catalogRepositoryProvider).products(sort: ProductSort.newest, size: 10)).items);

final productDetailProvider = FutureProvider.family<ProductDetail, String>(
  (ref, slug) => ref.watch(catalogRepositoryProvider).product(slug),
);

/// What the Shop tab is showing.
class ShopQuery {
  const ShopQuery({this.category, this.search = '', this.sort = ProductSort.popular, this.dealsOnly = false});

  final String? category;
  final String search;
  final ProductSort sort;
  final bool dealsOnly;

  ShopQuery copyWith({String? Function()? category, String? search, ProductSort? sort, bool? dealsOnly}) => ShopQuery(
        category: category == null ? this.category : category(),
        search: search ?? this.search,
        sort: sort ?? this.sort,
        dealsOnly: dealsOnly ?? this.dealsOnly,
      );

  @override
  bool operator ==(Object other) =>
      other is ShopQuery &&
      other.category == category &&
      other.search == search &&
      other.sort == sort &&
      other.dealsOnly == dealsOnly;

  @override
  int get hashCode => Object.hash(category, search, sort, dealsOnly);
}

class ShopState {
  const ShopState({
    this.query = const ShopQuery(),
    this.items = const [],
    this.totalItems = 0,
    this.nextPage = 0,
    this.hasMore = true,
    this.loading = false,
    this.error,
  });

  final ShopQuery query;
  final List<ProductCard> items;
  final int totalItems;
  final int nextPage;
  final bool hasMore;
  final bool loading;
  final String? error;

  bool get isFirstLoad => items.isEmpty && loading;
}

final shopControllerProvider = NotifierProvider<ShopController, ShopState>(ShopController.new);

/// Paged product list for the Shop tab. Changing the query starts again from page 0.
class ShopController extends Notifier<ShopState> {
  static const pageSize = 20;

  // Ignores responses for a query that has since changed.
  int _generation = 0;

  @override
  ShopState build() => const ShopState();

  Future<void> setQuery(ShopQuery query) async {
    if (query == state.query && (state.items.isNotEmpty || state.loading)) return;
    _generation++;
    state = ShopState(query: query);
    await loadMore();
  }

  Future<void> refresh() async {
    _generation++;
    state = ShopState(query: state.query);
    await loadMore();
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    final generation = _generation;
    final query = state.query;
    state = ShopState(
      query: query,
      items: state.items,
      totalItems: state.totalItems,
      nextPage: state.nextPage,
      loading: true,
    );
    try {
      final page = await ref.read(catalogRepositoryProvider).products(
            category: query.category,
            query: query.search,
            dealsOnly: query.dealsOnly,
            sort: query.sort,
            page: state.nextPage,
            size: pageSize,
          );
      if (generation != _generation) return;
      state = ShopState(
        query: query,
        items: [...state.items, ...page.items],
        totalItems: page.totalItems,
        nextPage: page.page + 1,
        hasMore: page.hasMore,
      );
    } on ApiException catch (e) {
      if (generation != _generation) return;
      state = ShopState(
        query: query,
        items: state.items,
        totalItems: state.totalItems,
        nextPage: state.nextPage,
        error: e.message,
      );
    }
  }
}
