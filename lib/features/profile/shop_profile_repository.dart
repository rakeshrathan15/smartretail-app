import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';

/// The shop owner's shop details and location, from /api/me/shop-profile.
class ShopProfile {
  const ShopProfile({
    required this.shopName,
    required this.ownerName,
    required this.phone,
    required this.gstNumber,
    required this.address,
    required this.city,
    required this.pincode,
    required this.location,
    required this.complete,
  });

  final String? shopName;
  final String? ownerName;
  final String? phone;
  final String? gstNumber;
  final String? address;
  final String? city;
  final String? pincode;
  final LatLng? location;
  final bool complete;

  factory ShopProfile.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'] as num?;
    final lng = json['lng'] as num?;
    return ShopProfile(
      shopName: json['shopName'] as String?,
      ownerName: json['ownerName'] as String?,
      phone: json['phone'] as String?,
      gstNumber: json['gstNumber'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      pincode: json['pincode'] as String?,
      location: lat != null && lng != null ? LatLng(lat.toDouble(), lng.toDouble()) : null,
      complete: json['complete'] as bool? ?? false,
    );
  }
}

final shopProfileRepositoryProvider = Provider((ref) => ShopProfileRepository(ref.watch(dioProvider)));

final shopProfileProvider = FutureProvider<ShopProfile>((ref) => ref.watch(shopProfileRepositoryProvider).get());

class ShopProfileRepository {
  ShopProfileRepository(this._dio);

  final Dio _dio;

  Future<ShopProfile> get() async {
    try {
      return ShopProfile.fromJson((await _dio.get<Map<String, dynamic>>('/api/me/shop-profile')).data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ShopProfile> save({
    required String shopName,
    required String ownerName,
    required String phone,
    required String? gstNumber,
    required String address,
    required String city,
    required String pincode,
    required LatLng location,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>('/api/me/shop-profile', data: {
        'shopName': shopName,
        'ownerName': ownerName,
        'phone': phone,
        'gstNumber': gstNumber,
        'address': address,
        'city': city,
        'state': 'Telangana',
        'pincode': pincode,
        'lat': location.latitude,
        'lng': location.longitude,
      });
      return ShopProfile.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Thrown when the phone cannot give a location; [message] is shown to the user.
class LocationUnavailable implements Exception {
  const LocationUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The phone's current position, asking for permission first. Replaced in tests.
final currentLocationProvider = Provider<Future<LatLng> Function()>((ref) => () async {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationUnavailable('Turn on location (GPS), or tap your shop on the map.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw const LocationUnavailable('Location access was not allowed. Tap your shop on the map instead.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      return LatLng(position.latitude, position.longitude);
    });

/// Whether to load map tiles from OpenStreetMap. Tests turn this off (no network there).
final mapTilesEnabledProvider = Provider<bool>((ref) => true);
