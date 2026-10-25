import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../core/token_storage.dart';
import 'auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider)),
);

class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStorage _tokens;

  /// [identifier] is an email address or a mobile number.
  Future<UserSummary> login(String identifier, String password) =>
      _authenticate('/api/auth/login', {'identifier': identifier, 'password': password});

  Future<UserSummary> register({
    required String fullName,
    String? email,
    String? phone,
    required String password,
  }) =>
      _authenticate('/api/auth/register', {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      });

  Future<bool> hasSession() async => await _tokens.readRefreshToken() != null;

  Future<UserSummary> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/me');
      return UserSummary.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokens.readRefreshToken();
    await _tokens.clear();
    if (refreshToken == null) return;
    try {
      await _dio.post<void>('/api/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException {
      // Already signed out locally; the token expires on its own if the server was unreachable.
    }
  }

  Future<UserSummary> _authenticate(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      final data = response.data!;
      await _tokens.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return UserSummary.fromJson(data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
