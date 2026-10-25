import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Backend URL. Override with `--dart-define=API_BASE_URL=http://192.168.1.10:8080`
  /// when running on a physical phone.
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // The Android emulator reaches the host machine at 10.0.2.2, not localhost.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
