import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary     = Color(0xFF534AB7);
  static const Color primaryDark = Color(0xFF3C3489);
  static const Color success     = Color(0xFF1D9E75);
  static const Color warning     = Color(0xFFBA7517);
  static const Color danger      = Color(0xFFE24B4A);
  static const Color info        = Color(0xFF185FA5);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F0);
    final surface= isDark ? const Color(0xFF242424) : Colors.white;
    final onBg   = isDark ? Colors.white : const Color(0xFF1A1A19);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: success,
        onSecondary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: surface,
        onSurface: onBg,
        surfaceContainerHighest: bg,
        outline: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0DED6),
      ),
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE8E6DE),
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: onBg,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
        iconTheme: IconThemeData(color: onBg),
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE8E6DE),
            width: 0.5,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0DED6),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0DED6),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: primary),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        ),
      ),
      textTheme: TextTheme(
        displayLarge:  TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, color: onBg),
        headlineMedium:TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: onBg, fontSize: 20),
        titleLarge:    TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: onBg, fontSize: 16),
        titleMedium:   TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, color: onBg, fontSize: 14),
        bodyLarge:     TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, color: onBg, fontSize: 15),
        bodyMedium:    TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, color: onBg, fontSize: 13),
        bodySmall:     TextStyle(fontFamily: 'Inter', color: isDark ? const Color(0xFF999999) : const Color(0xFF888780), fontSize: 12),
        labelSmall:    TextStyle(fontFamily: 'Inter', color: isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA), fontSize: 11),
      ),
      fontFamily: 'Inter',
    );
  }
}
