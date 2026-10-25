import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Builds the Dio client used for every backend call.
///
/// Adds the bearer token to requests, and when a request fails with 401 it
/// exchanges the refresh token for a new pair once and retries. If the refresh
/// fails, the tokens are cleared and [onSessionExpired] is called.
Dio createApiClient({
  required String baseUrl,
  required TokenStorage tokens,
  required void Function() onSessionExpired,
  HttpClientAdapter? adapter,
}) {
  final options = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    contentType: Headers.jsonContentType,
  );
  final dio = Dio(options);
  // A separate client for /refresh so it never passes through the interceptor below.
  final refreshDio = Dio(options);
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
    refreshDio.httpClientAdapter = adapter;
  }
  dio.interceptors.add(_AuthInterceptor(dio, refreshDio, tokens, onSessionExpired));
  return dio;
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._dio, this._refreshDio, this._tokens, this._onSessionExpired);

  static const _retriedKey = 'auth_retried';

  final Dio _dio;
  final Dio _refreshDio;
  final TokenStorage _tokens;
  final void Function() _onSessionExpired;

  bool _isAuthEndpoint(RequestOptions options) => options.path.startsWith('/api/auth/');

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isAuthEndpoint(options)) {
      final token = await _tokens.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 || _isAuthEndpoint(request) || request.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    // Errors are queued, so another request may already have refreshed the tokens.
    final current = await _tokens.readAccessToken();
    final sentWith = request.headers['Authorization'];
    final alreadyRefreshed = current != null && sentWith != 'Bearer $current';

    if (!alreadyRefreshed && !await _refresh()) {
      await _tokens.clear();
      _onSessionExpired();
      return handler.next(err);
    }

    try {
      final retry = request.copyWith(extra: {...request.extra, _retriedKey: true});
      retry.headers['Authorization'] = 'Bearer ${await _tokens.readAccessToken()}';
      handler.resolve(await _dio.fetch<dynamic>(retry));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final body = response.data!;
      await _tokens.save(
        accessToken: body['accessToken'] as String,
        refreshToken: body['refreshToken'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }
}
