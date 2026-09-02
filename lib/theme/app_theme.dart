import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF091017);
  static const Color panel = Color(0xFF101A24);
  static const Color panelElevated = Color(0xFF162330);
  static const Color accent = Color(0xFF61D6A8);
  static const Color warning = Color(0xFFF4C66D);
  static const Color danger = Color(0xFFFF7A7A);
  static const Color textMuted = Color(0xFF9BACBC);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: panel,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardColor: panel,
      dividerColor: const Color(0xFF22313E),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(height: 1.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panelElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }
}
