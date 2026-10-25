import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/error_retry.dart';
import '../../core/widgets/product_card_tile.dart';
import '../catalog/catalog_models.dart';
import '../catalog/catalog_providers.dart';

/// Product grid with search, sort, category and deals filters. The route's query
/// parameters (?category=colas&sort=NEWEST&deals=1&search=1) set the starting filters.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, required this.initialQuery, this.focusSearch = false});

  final ShopQuery initialQuery;
  final bool focusSearch;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;

  ShopController get _controller => ref.read(shopControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _applyRouteQuery();
  }

  @override
  void didUpdateWidget(ShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery || oldWidget.focusSearch != widget.focusSearch) {
      _applyRouteQuery();
    }
  }

  void _applyRouteQuery() {
    _search.text = widget.initialQuery.search;
    // Providers cannot be modified while the widget tree is building.
    Future.microtask(() => _controller.setQuery(widget.initialQuery));
    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600) _controller.loadMore();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final state = ref.read(shopControllerProvider);
      _controller.setQuery(state.query.copyWith(search: text.trim()));
    });
  }

  void _update(ShopQuery Function(ShopQuery) change) {
    _controller.setQuery(change(ref.read(shopControllerProvider).query));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shopControllerProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final query = state.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name, brand or flavour',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _onSearchChanged('');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              scrollDirection: Axis.horizontal,
              children: [
                for (final sort in ProductSort.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(sort.label),
                      selected: query.sort == sort,
                      onSelected: (_) => _update((q) => q.copyWith(sort: sort)),
                    ),
                  ),
                FilterChip(
                  avatar: const Icon(Icons.local_offer_outlined, size: 18),
                  label: const Text('Deals'),
                  selected: query.dealsOnly,
                  onSelected: (on) => _update((q) => q.copyWith(dealsOnly: on)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: query.category == null,
                    onSelected: (_) => _update((q) => q.copyWith(category: () => null)),
                  ),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category.name),
                      selected: query.category == category.slug,
                      onSelected: (_) => _update((q) => q.copyWith(category: () => category.slug)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildResults(state)),
        ],
      ),
    );
  }

  Widget _buildResults(ShopState state) {
    if (state.isFirstLoad) return const Center(child: CircularProgressIndicator());
    if (state.items.isEmpty && state.error != null) {
      return Center(child: ErrorRetry(message: state.error!, onRetry: _controller.refresh));
    }
    if (state.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No products match. Try another search or category.', textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            sliver: SliverToBoxAdapter(
              child: Text('${state.totalItems} products', style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 290,
              ),
              itemCount: state.items.length,
              itemBuilder: (_, i) => ProductCardTile(product: state.items[i]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Center(
                child: state.loading
                    ? const CircularProgressIndicator()
                    : state.error != null
                        ? TextButton(onPressed: _controller.loadMore, child: const Text('Couldn’t load more. Retry'))
                        : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
