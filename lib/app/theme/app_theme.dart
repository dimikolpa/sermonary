import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 40.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 18.0;
}

abstract final class AppSizes {
  static const editorWidth = 780.0;
  static const compactBreakpoint = 720.0;
  static const expandedBreakpoint = 1100.0;
}

abstract final class AppMotion {
  static const quick = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 240);
}

abstract final class AppColors {
  static const seed = Color(0xFF315A4C);
  static const brass = Color(0xFF8A7246);
  static const paper = Color(0xFFF8F5EE);
  static const ink = Color(0xFF252725);
  static const error = Color(0xFF9B3F3F);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: brightness,
    surface: dark ? const Color(0xFF1C1F1D) : AppColors.paper,
  );
  final textTheme = Typography.material2021().black.apply(
    bodyColor: dark ? const Color(0xFFE9E7E0) : AppColors.ink,
    displayColor: dark ? const Color(0xFFF3F1EA) : AppColors.ink,
    fontFamily: '.AppleSystemUIFont',
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF171917)
        : const Color(0xFFF5F1E8),
    textTheme: textTheme.copyWith(
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.65, fontSize: 17),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.55),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: TextStyle(color: scheme.onInverseSurface),
    ),
  );
}
