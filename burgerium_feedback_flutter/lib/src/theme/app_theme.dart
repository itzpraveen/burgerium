import 'package:flutter/material.dart';

class AppPalette {
  static const canvas = Color(0xFFF7E6C8);
  static const surface = Color(0xFFFFF5E8);
  static const surfaceStrong = Color(0xFFFFE7BA);
  static const card = Color(0xFFFFF9F1);
  static const ink = Color(0xFF24140B);
  static const inkSoft = Color(0xFF5C4638);
  static const ember = Color(0xFFF39B32);
  static const emberDeep = Color(0xFFB85C1E);
  static const amber = Color(0xFFFFC44D);
  static const sand = Color(0xFFFFE0A7);
  static const danger = Color(0xFFB23A1F);
  static const success = Color(0xFF2E7D5B);
  static const outline = Color(0x1F24140B);
}

ThemeData buildBurgeriumTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppPalette.ember,
        brightness: Brightness.light,
        primary: AppPalette.ember,
        secondary: AppPalette.amber,
        surface: AppPalette.surface,
      ).copyWith(
        surface: AppPalette.surface,
        onSurface: AppPalette.ink,
        onPrimary: AppPalette.ink,
        tertiary: AppPalette.emberDeep,
        error: AppPalette.danger,
      );
  final baseTheme = ThemeData(useMaterial3: true, colorScheme: colorScheme);
  final baseText = baseTheme.textTheme.apply(
    bodyColor: AppPalette.inkSoft,
    displayColor: AppPalette.ink,
  );

  return baseTheme.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF6F0E6),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: baseText.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppPalette.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.82),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontSize: 32,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: AppPalette.ink,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 30,
        height: 1.08,
        fontWeight: FontWeight.w700,
        color: AppPalette.ink,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: AppPalette.ink,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 18,
        height: 1.12,
        fontWeight: FontWeight.w700,
        color: AppPalette.ink,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppPalette.ink,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.42,
        color: AppPalette.inkSoft,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.36,
        color: AppPalette.inkSoft,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.86),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.ember, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.danger, width: 1.5),
      ),
      hintStyle: baseText.bodyMedium?.copyWith(
        color: AppPalette.inkSoft.withValues(alpha: 0.72),
      ),
      labelStyle: baseText.bodyMedium?.copyWith(color: AppPalette.inkSoft),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppPalette.ink,
      contentTextStyle: baseText.bodyMedium?.copyWith(
        color: AppPalette.surface,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      side: const BorderSide(color: AppPalette.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      selectedColor: AppPalette.sand,
      backgroundColor: Colors.white.withValues(alpha: 0.78),
      labelStyle: baseText.labelLarge?.copyWith(
        color: AppPalette.ink,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: AppPalette.ink,
        backgroundColor: AppPalette.ember,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.ink,
        side: const BorderSide(color: AppPalette.outline),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    dividerColor: AppPalette.outline,
  );
}
