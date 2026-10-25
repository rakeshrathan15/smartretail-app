import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../cart/cart_controller.dart';
import '../catalog/catalog_models.dart';
import 'checkout_models.dart';

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) => CheckoutRepository(ref.watch(dioProvider)));

class AddressInput {
  const AddressInput({
    required this.label,
    required this.fullName,
    required this.phone,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.pincode,
    this.makeDefault = false,
  });

  final String label;
  final String fullName;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String pincode;
  final bool makeDefault;

  Map<String, dynamic> toJson() => {
        'label': label,
        'fullName': fullName,
        'phone': phone,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'city': city,
        'pincode': pincode,
        'makeDefault': makeDefault,
      };
}

class CheckoutRepository {
  CheckoutRepository(this._dio);

  final Dio _dio;

  Future<Quote> quote(List<CartLine> lines, String? couponCode) async =>
      Quote.fromJson(await _send('POST', '/api/checkout/quote', {'items': _items(lines), 'couponCode': couponCode}));

  Future<OrderDetail> placeOrder({
    required List<CartLine> lines,
    required String? couponCode,
    required String addressId,
    required PaymentMethod method,
    required String? paymentScreenshot,
    required String? notes,
    required double expectedTotal,
  }) async =>
      OrderDetail.fromJson(await _send('POST', '/api/orders', {
        'items': _items(lines),
        'couponCode': couponCode,
        'addressId': addressId,
        'paymentMethod': method.apiValue,
        'paymentScreenshot': paymentScreenshot,
        'notes': notes,
        'expectedTotal': expectedTotal,
      }));

  /// Uploads the UPI screenshot and returns the reference to send with the order. Only admins can view it.
  Future<String> uploadPaymentScreenshot(Uint8List bytes, String fileName) async {
    final form = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: fileName)});
    return (await _send('POST', '/api/me/payment-screenshots', form))['reference'] as String;
  }

  Future<List<Address>> addresses() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/me/addresses');
      return response.data!.map((e) => Address.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Address> addAddress(AddressInput input) async =>
      Address.fromJson(await _send('POST', '/api/me/addresses', input.toJson()));

  Future<PageResult<OrderSummary>> myOrders({int page = 0}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/me/orders', queryParameters: {'page': page, 'size': 30});
      return PageResult.fromJson(response.data!, OrderSummary.fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<OrderDetail> order(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/me/orders/$id');
      return OrderDetail.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static List<Map<String, dynamic>> _items(List<CartLine> lines) =>
      [for (final l in lines) {'productId': l.productId, 'quantity': l.quantity}];

  Future<Map<String, dynamic>> _send(String method, String path, Object body) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(path, data: body, options: Options(method: method));
      return response.data!;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
