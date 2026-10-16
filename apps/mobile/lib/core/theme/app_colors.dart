import 'package:flutter/material.dart';

/// Palet warna Kelasxtra.
///
/// Dipilih agar terasa ceria & berenergi (cocok remaja SMP/SMA) tapi tetap
/// tepercaya: indigo sebagai warna utama, ungu sebagai aksen gradien.
abstract final class AppColors {
  static const primary = Color(0xFF4F46E5);
  static const primaryDark = Color(0xFF4338CA);
  static const accent = Color(0xFF7C3AED);
  static const accentAlt = Color(0xFF06B6D4);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  static const star = Color(0xFFFBBF24);

  // Terang
  static const bgLight = Color(0xFFF6F7FB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE5E8EF);
  static const textLight = Color(0xFF111827);
  static const textMutedLight = Color(0xFF6B7280);

  // Gelap
  static const bgDark = Color(0xFF0B1020);
  static const surfaceDark = Color(0xFF161C2E);
  static const borderDark = Color(0xFF2A3350);
  static const textDark = Color(0xFFF3F4F6);
  static const textMutedDark = Color(0xFF9CA3AF);

  /// Gradien utama untuk header, tombol besar, dan kartu unggulan.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  /// Gradien lembut (hero/banner) — tidak mencolok.
  static const gradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accentAlt],
  );
}
