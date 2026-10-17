import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Jarak & bentuk yang konsisten di seluruh aplikasi.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Padding standar tepi layar.
  static const page = EdgeInsets.symmetric(horizontal: 20);
}

abstract final class AppRadius {
  static const sm = 9.0;
  static const md = 12.0;
  static const lg = 18.0;
  static const xl = 24.0;

  static const card = BorderRadius.all(Radius.circular(lg));
  static const button = BorderRadius.all(Radius.circular(14));
  static const sheet = BorderRadius.vertical(top: Radius.circular(xl));
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = _scheme(brightness);
    final text = AppTypography.textTheme(
      isLight ? AppColors.textLight : AppColors.textDark,
      isLight ? AppColors.textMutedLight : AppColors.textMutedDark,
    );
    final background = isLight ? AppColors.bgLight : AppColors.bgDark;
    final surface = isLight ? AppColors.surfaceLight : AppColors.surfaceDark;
    final border = isLight ? AppColors.borderLight : AppColors.borderDark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: border),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? Colors.white : AppColors.surfaceDark,
        side: BorderSide(color: border),
        labelStyle: text.bodySmall,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? AppColors.textLight : AppColors.surfaceDark,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
    );
  }

  static ColorScheme _scheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );
    if (isLight) {
      return base.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textLight,
        onSurfaceVariant: AppColors.textMutedLight,
        error: AppColors.danger,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderLight,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: AppColors.bgLight,
        surfaceContainer: AppColors.bgLight,
        surfaceContainerHigh: AppColors.bgLight,
        surfaceContainerHighest: AppColors.bgLight,
      );
    }
    return base.copyWith(
      primary: const Color(0xFF8B87F5),
      secondary: const Color(0xFFA78BFA),
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textMutedDark,
      error: const Color(0xFFF87171),
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderDark,
      surfaceContainerLowest: AppColors.bgDark,
      surfaceContainerLow: AppColors.surfaceDark,
      surfaceContainer: AppColors.surfaceDark,
      surfaceContainerHigh: AppColors.surfaceDark,
      surfaceContainerHighest: AppColors.surfaceDark,
    );
  }
}
