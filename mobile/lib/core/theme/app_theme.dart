import 'package:flutter/material.dart';

/// Brand tokens + Material 3 theme. RTL is applied at MaterialApp level.
/// Palette pulled from the logo: warm orange on near-black.
class AppTheme {
  static const Color brand = Color(0xFFE87722);      // logo orange
  static const Color brandDark = Color(0xFF1F1B1A);  // logo background
  static const Color surface = Color(0xFFFDFAF6);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Cairo', // shipped by Google Fonts network at runtime? We just use system Arabic fallback for now.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
