import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografi Kelasxtra.
///
/// WorkSans dipakai agar sejalan dengan template acuan: tegas, bersih, dan
/// tetap ramah. Ukuran body tetap >=15sp agar nyaman dibaca di HP.
///
/// Catatan: google_fonts mengunduh font saat pertama dijalankan (perlu internet,
/// lalu di-cache). Untuk rilis offline total, bundel file font lalu pakai
/// `GoogleFonts.workSans(... asset:)`.
abstract final class AppTypography {
  static TextTheme textTheme(Color textColor, Color mutedColor) {
    final base = GoogleFonts.workSansTextTheme().apply(
      bodyColor: textColor,
      displayColor: textColor,
    );
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.6,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 14, height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 13, height: 1.45),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 11,
        height: 1.4,
        color: mutedColor,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: mutedColor,
      ),
    );
  }
}
