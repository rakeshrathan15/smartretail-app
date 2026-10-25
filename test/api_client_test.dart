import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_retail_app/core/api_client.dart';
import 'package:smart_retail_app/core/api_exception.dart';
import 'package:smart_retail_app/core/token_storage.dart';

import 'fake_backend.dart';

void main() {
  test('refreshes an expired access token once and retries the request', () async {
    final tokens = InMemoryTokenStorage();
    await tokens.save(accessToken: 'expired', refreshToken: 'refresh-1');
    final backend = FakeBackend({
      'GET /api/me': (req) => req.headers['Authorization'] == 'Bearer access-2'
          ? FakeResponse(200, userJson())
          : const FakeResponse(401),
      'POST /api/auth/refresh': (req) => FakeResponse(200, authJson(access: 'access-2', refresh: 'refresh-2')),
    });
    final dio = createApiClient(baseUrl: 'http://test', tokens: tokens, onSessionExpired: () {}, adapter: backend);

    final response = await dio.get<Map<String, dynamic>>('/api/me');

    expect(response.statusCode, 200);
    expect(await tokens.readAccessToken(), 'access-2');
    expect(await tokens.readRefreshToken(), 'refresh-2');
    expect(backend.requests.map((r) => r.path), ['/api/me', '/api/auth/refresh', '/api/me']);
  });

  test('clears tokens and reports expiry when the refresh token is rejected', () async {
    final tokens = InMemoryTokenStorage();
    await tokens.save(accessToken: 'expired', refreshToken: 'revoked');
    var expired = false;
    final backend = FakeBackend({
      'GET /api/me': (_) => const FakeResponse(401),
      'POST /api/auth/refresh': (_) => const FakeResponse(401, {'detail': 'Session expired'}),
    });
    final dio = createApiClient(
      baseUrl: 'http://test',
      tokens: tokens,
      onSessionExpired: () => expired = true,
      adapter: backend,
    );

    await expectLater(dio.get<void>('/api/me'), throwsA(isA<DioException>()));
    expect(expired, isTrue);
    expect(await tokens.readRefreshToken(), isNull);
  });

  test('reads message and field errors from a problem-detail response', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/auth/register'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/auth/register'),
        statusCode: 400,
        data: {
          'detail': 'Validation failed',
          'errors': {'email': 'must be a well-formed email address'},
        },
      ),
    );

    final apiError = ApiException.fromDio(error);

    expect(apiError.message, 'Validation failed');
    expect(apiError.statusCode, 400);
    expect(apiError.fieldErrors['email'], 'must be a well-formed email address');
  });
}
