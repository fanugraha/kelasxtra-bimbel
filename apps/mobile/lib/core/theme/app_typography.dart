import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografi Kelasxtra.
///
/// Memakai **Nunito** — font bulat & ramah, nyaman dibaca remaja. Ukuran body
/// sengaja >= 15sp agar mudah dibaca di HP saat mengerjakan soal.
///
/// Catatan: google_fonts mengunduh font saat pertama dijalankan (perlu internet,
/// lalu di-cache). Untuk rilis offline total, bundel file font lalu pakai
/// `GoogleFonts.nunito(... asset:)` (ponytail: cukup runtime fetch untuk sekarang).
abstract final class AppTypography {
  static TextTheme textTheme(Color textColor, Color mutedColor) {
    final base = GoogleFonts.nunitoTextTheme().apply(
      bodyColor: textColor,
      displayColor: textColor,
    );
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(fontSize: 30, fontWeight: FontWeight.w800),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w800),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 23, fontWeight: FontWeight.w800),
      titleLarge: base.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
      titleMedium: base.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      titleSmall: base.titleSmall?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
      bodySmall: base.bodySmall?.copyWith(fontSize: 13, color: mutedColor),
      labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}
