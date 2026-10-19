import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Jarak & bentuk yang konsisten di seluruh aplikasi.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;

  /// Jarak antar section halaman.
  static const xl = 18.0;
  static const xxl = 32.0;

  /// Padding standar tepi layar.
  static const page = EdgeInsets.symmetric(horizontal: 16);
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;

  static const card = BorderRadius.all(Radius.circular(lg));
  static const button = BorderRadius.all(Radius.circular(16));
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

    final palette = isLight ? AppPalette.light : AppPalette.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [palette],
      scaffoldBackgroundColor: background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
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
        height: 72,
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 9.5,
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
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          // Mode gelap mengikuti referensi: tombol utama putih dengan teks gelap.
          backgroundColor: isLight ? scheme.primary : Colors.white,
          foregroundColor: isLight ? scheme.onPrimary : AppColors.bgDark,
          // Nonaktif = abu netral tanpa warna brand: jelas "belum bisa ditekan".
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: text.labelLarge,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          foregroundColor: scheme.onSurface,
          backgroundColor: isLight ? surface : Colors.transparent,
          side: BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? AppColors.surfaceAltLight
            : AppColors.surfaceAltDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        floatingLabelStyle: TextStyle(color: scheme.primary, fontSize: 11),
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
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: scheme.primary,
        side: BorderSide(color: border),
        labelStyle: text.bodySmall,
        secondaryLabelStyle: text.bodySmall?.copyWith(color: scheme.onPrimary),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.42),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? AppColors.textLight
            : AppColors.surfaceAltDark,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: border,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: border),
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
        onPrimary: Colors.white,
        secondary: AppColors.accentAlt,
        onSecondary: AppColors.textLight,
        tertiary: AppColors.accent,
        onTertiary: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textLight,
        onSurfaceVariant: AppColors.textMutedLight,
        error: AppColors.danger,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderLight,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: AppColors.surfaceAltLight,
        surfaceContainer: AppColors.bgLight,
        surfaceContainerHigh: AppColors.surfaceAltLight,
        surfaceContainerHighest: AppColors.borderLight,
      );
    }
    return base.copyWith(
      primary: AppPalette.dark.brand,
      onPrimary: AppPalette.dark.onBrand,
      secondary: AppColors.accentAlt,
      onSecondary: AppColors.bgDark,
      tertiary: AppColors.accent,
      onTertiary: AppColors.bgDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textMutedDark,
      error: AppPalette.dark.danger,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderDark,
      surfaceContainerLowest: AppColors.bgDark,
      surfaceContainerLow: AppColors.surfaceDark,
      surfaceContainer: AppColors.surfaceAltDark,
      surfaceContainerHigh: AppColors.surfaceAltDark,
      surfaceContainerHighest: AppColors.borderDark,
    );
  }
}
