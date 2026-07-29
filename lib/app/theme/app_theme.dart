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
  static const sidebarWidth = 172.0;
  static const entryListWidth = 210.0;
  static const editorWidth = 620.0;
  static const outlineWidth = 580.0;
  static const splitWidth = 1160.0;
  static const compactBreakpoint = 720.0;
  static const expandedBreakpoint = 1100.0;
}

abstract final class AppMotion {
  static const quick = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 240);
}

abstract final class AppColors {
  static const seed = Color(0xFF77736A);
  static const paper = Color(0xFFF9F8F5);
  static const sidebar = Color(0xFFF3F2EE);
  static const ink = Color(0xFF1C1B18);
  static const darkPaper = Color(0xFF1A1917);
  static const darkInk = Color(0xFFE5E3DC);
  static const muted = Color(0xFFEAEAE6);
  static const mutedForeground = Color(0xFF8A8980);
  static const darkSidebar = Color(0xFF201F1B);
  static const darkMuted = Color(0xFF2A2825);
  static const darkMutedForeground = Color(0xFF7A7872);
  static const highlight = Color(0xFFFCD61C);
  static const error = Color(0xFFB94A3B);
}

abstract final class AppTypography {
  static const ui = 'DM Sans';
  static const editor = 'Literata';
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: brightness,
  );
  final scheme = baseScheme.copyWith(
    surface: dark ? AppColors.darkPaper : AppColors.paper,
    onSurface: dark ? AppColors.darkInk : AppColors.ink,
    surfaceContainerLowest: dark
        ? AppColors.darkPaper
        : const Color(0xFFFCFBF8),
    surfaceContainerLow: dark ? AppColors.darkSidebar : AppColors.sidebar,
    surfaceContainer: dark ? AppColors.darkMuted : AppColors.muted,
    outline: dark
        ? AppColors.darkInk.withValues(alpha: 0.07)
        : AppColors.ink.withValues(alpha: 0.08),
    outlineVariant: dark
        ? AppColors.darkInk.withValues(alpha: 0.07)
        : AppColors.ink.withValues(alpha: 0.08),
    primary: dark ? AppColors.darkInk : AppColors.ink,
    onPrimary: dark ? AppColors.ink : AppColors.paper,
    primaryContainer: dark ? AppColors.darkMuted : AppColors.muted,
    onPrimaryContainer: dark ? AppColors.darkInk : AppColors.ink,
    secondaryContainer: dark ? AppColors.darkMuted : AppColors.muted,
    error: AppColors.error,
  );
  final textTheme = Typography.material2021().black.apply(
    bodyColor: dark ? AppColors.darkInk : AppColors.ink,
    displayColor: dark ? AppColors.darkInk : AppColors.ink,
    fontFamily: AppTypography.ui,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme.copyWith(
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.18,
        letterSpacing: -0.7,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.4,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.65, fontSize: 16),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.5),
      labelSmall: textTheme.labelSmall?.copyWith(
        letterSpacing: 0.25,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 58,
      titleTextStyle: textTheme.titleSmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      shape: Border(
        bottom: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.35)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        visualDensity: VisualDensity.compact,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      minTileHeight: 38,
    ),
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
