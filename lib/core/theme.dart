import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const brandNavy = Color(0xFF1E3A8A);
  static const brandRed = Color(0xFFDC2626);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandNavy,
      primary: brandNavy,
      secondary: brandRed,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: brandNavy,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    );
  }
}
