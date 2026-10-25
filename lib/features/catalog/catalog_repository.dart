import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import 'catalog_models.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => CatalogRepository(ref.watch(dioProvider)));

class CatalogRepository {
  CatalogRepository(this._dio);

  final Dio _dio;

  Future<List<Category>> categories() async =>
      (await _getList('/api/categories')).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<BannerItem>> banners() async =>
      (await _getList('/api/banners')).map((e) => BannerItem.fromJson(e as Map<String, dynamic>)).toList();

  Future<StoreInfo> storeInfo() async => StoreInfo.fromSettings(await _getMap('/api/settings/public'));

  Future<PageResult<ProductCard>> products({
    String? category,
    String? query,
    bool dealsOnly = false,
    ProductSort sort = ProductSort.popular,
    int page = 0,
    int size = 20,
  }) async {
    final json = await _getMap('/api/products', {
      'category': ?category,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (dealsOnly) 'deals': true,
      'sort': sort.apiValue,
      'page': page,
      'size': size,
    });
    return PageResult.fromJson(json, ProductCard.fromJson);
  }

  Future<ProductDetail> product(String slug) async =>
      ProductDetail.fromJson(await _getMap('/api/products/${Uri.encodeComponent(slug)}'));

  Future<Map<String, dynamic>> _getMap(String path, [Map<String, dynamic>? query]) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return response.data!;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<dynamic>> _getList(String path) async {
    try {
      final response = await _dio.get<List<dynamic>>(path);
      return response.data!;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
