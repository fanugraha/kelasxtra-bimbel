import 'package:flutter/material.dart';

/// Palet warna Kelasxtra.
///
/// Mengikuti bahasa visual template "Design Course + Hotel Booking":
/// latar terang, kartu putih, aksen cyan/teal, teks navy. Warna utama dibuat
/// cukup gelap agar teks putih di tombol tetap lolos kontras WCAG AA.
abstract final class AppColors {
  static const primary = Color(0xFF007596);
  static const primaryDark = Color(0xFF00657F);
  static const accent = Color(0xFF00B6F0);
  static const accentAlt = Color(0xFF54D3C2);
  static const coral = Color(0xFFFF7A59);

  static const success = Color(0xFF117962);
  static const warning = Color(0xFFA55A05);
  static const danger = Color(0xFFC23636);
  static const info = Color(0xFF2A6BBC);

  static const star = Color(0xFFFFB020);

  // Terang
  static const bgLight = Color(0xFFF3F7F9);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFF6FAFB);
  static const borderLight = Color(0xFFE3ECEF);
  static const textLight = Color(0xFF17262A);
  static const textMutedLight = Color(0xFF5D7680);

  // Gelap
  static const bgDark = Color(0xFF0C161A);
  static const surfaceDark = Color(0xFF132329);
  static const surfaceAltDark = Color(0xFF1A2F36);
  static const borderDark = Color(0xFF27424C);
  static const textDark = Color(0xFFF2F8FA);
  static const textMutedDark = Color(0xFF9DB6BF);

  /// Gradien utama header/hero. Cukup gelap agar teks putih aman dibaca.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF007FA3), Color(0xFF0E8F8A)],
  );

  /// Gradien lembut untuk aksen dekoratif (tanpa teks putih kecil).
  static const gradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentAlt],
  );
}
