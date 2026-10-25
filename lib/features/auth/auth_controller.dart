import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_models.dart';
import 'auth_repository.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, UserSummary?>(AuthController.new);

/// The signed-in user, or null when signed out. Loading while the saved session is checked.
class AuthController extends AsyncNotifier<UserSummary?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<UserSummary?> build() async {
    if (!await _repo.hasSession()) return null;
    try {
      return await _repo.me();
    } catch (_) {
      return null;
    }
  }

  /// Throws [ApiException] so the form can show the message; state stays signed out.
  Future<void> login(String identifier, String password) async {
    state = AsyncData(await _repo.login(identifier, password));
  }

  Future<void> register({
    required String fullName,
    String? email,
    String? phone,
    required String password,
  }) async {
    state = AsyncData(await _repo.register(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
    ));
  }

  Future<void> refreshUser() async {
    state = AsyncData(await _repo.me());
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  /// Called by the API client when the refresh token is no longer valid.
  void onSessionExpired() {
    state = const AsyncData(null);
  }
}
