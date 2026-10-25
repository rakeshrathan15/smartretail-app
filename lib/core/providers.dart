import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import 'api_client.dart';
import 'config.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.apiBaseUrl);

/// Turns a server path such as "/uploads/products/x.jpg" into a full URL; full URLs pass through.
final mediaUrlProvider = Provider<String Function(String)>((ref) {
  final base = ref.watch(apiBaseUrlProvider);
  return (path) => path.startsWith('/') ? '$base$path' : path;
});

final dioProvider = Provider<Dio>((ref) {
  return createApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    tokens: ref.watch(tokenStorageProvider),
    onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
});
