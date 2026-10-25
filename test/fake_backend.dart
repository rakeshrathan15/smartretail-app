import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = FakeResponse Function(RequestOptions request);

class FakeResponse {
  const FakeResponse(this.status, [this.body]);

  final int status;
  final Object? body;
}

/// A Dio adapter that answers requests from [routes] ("POST /api/auth/login") and records them.
class FakeBackend implements HttpClientAdapter {
  FakeBackend(this.routes);

  final Map<String, FakeHandler> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    final response = handler?.call(options) ?? const FakeResponse(404, {'detail': 'Not found'});
    return ResponseBody.fromString(
      response.body == null ? '' : jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> userJson({String fullName = 'Ravi Kumar'}) => {
      'id': '7b0c1c8e-5a43-4c0f-9a51-0d5f1b2f8c11',
      'email': null,
      'phone': '9876543210',
      'fullName': fullName,
      'roles': ['CUSTOMER'],
      'shopProfileComplete': false,
    };

Map<String, dynamic> authJson({String access = 'access-1', String refresh = 'refresh-1'}) => {
      'accessToken': access,
      'refreshToken': refresh,
      'tokenType': 'Bearer',
      'expiresIn': 900,
      'user': userJson(),
    };

Map<String, dynamic> productJson(String slug, String name, {String brand = 'Thums Up', double price = 420, double? original}) => {
      'id': 'id-$slug',
      'slug': slug,
      'name': name,
      'brand': brand,
      'categoryId': 'cat-colas',
      'unitVolumeMl': 750,
      'unitsPerCase': 12,
      'price': price,
      'originalPrice': original,
      'lowestPrice': price * 0.85,
      'imageUrl': null,
      'inStock': true,
      'badge': null,
    };

Map<String, dynamic> pageJson(List<Map<String, dynamic>> items) =>
    {'items': items, 'page': 0, 'size': 20, 'totalItems': items.length, 'totalPages': 1};

/// Storefront endpoints with a small catalog: two categories, a deal and a juice.
Map<String, FakeHandler> catalogRoutes() => {
      'GET /api/settings/public': (_) =>
          const FakeResponse(200, {'store_name': "S'Mart Retail", 'store_open': 'true', 'store_address': 'Telangana, India'}),
      'GET /api/banners': (_) => const FakeResponse(200, [
            {'id': 'b1', 'title': 'Bulk case pricing', 'subtitle': 'Slab discounts apply', 'ctaText': 'Shop cases', 'link': '/shop'},
          ]),
      'GET /api/categories': (_) => const FakeResponse(200, [
            {'id': 'cat-colas', 'name': 'Colas', 'slug': 'colas'},
            {'id': 'cat-juices', 'name': 'Juices', 'slug': 'juices'},
            // Wraps to two lines under its icon.
            {'id': 'cat-water', 'name': 'Packaged Water', 'slug': 'packaged-water'},
          ]),
      'GET /api/products': (req) {
        final params = req.queryParameters;
        if (params['category'] == 'juices') {
          return FakeResponse(200, pageJson([productJson('maaza-600', 'Maaza Mango 600ml', brand: 'Maaza', price: 900)]));
        }
        return FakeResponse(200, pageJson([
          productJson('thums-up-750', 'Thums Up 750ml PET', original: 480),
          if (params['deals'] != true) productJson('maaza-600', 'Maaza Mango 600ml', brand: 'Maaza', price: 900),
        ]));
      },
      'GET /api/products/thums-up-750': (_) => FakeResponse(200, {
            ...productJson('thums-up-750', 'Thums Up 750ml PET', original: 480),
            'flavor': 'Cola',
            'category': {'id': 'cat-colas', 'name': 'Colas', 'slug': 'colas'},
            'weight': null,
            'description': 'Strong fizzy cola.',
            'ingredients': null,
            'images': <dynamic>[],
            'slabs': [
              {'minQty': 10, 'maxQty': 24, 'pricePerCase': 378},
              {'minQty': 25, 'maxQty': null, 'pricePerCase': 357},
            ],
          }),
    };
