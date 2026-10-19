import 'package:flutter/material.dart';

/// Tingkat penguasaan topik — ambang sama dengan [TopicStat.kategori].
enum Mastery {
  kuat('Kuat', '75–100%', Icons.check_circle_rounded),
  cukup('Cukup', '50–74%', Icons.adjust_rounded),
  lemah('Perlu latihan', '0–49%', Icons.flag_rounded);

  const Mastery(this.label, this.range, this.icon);
  final String label;
  final String range;
  final IconData icon;

  static Mastery of(double accuracy) => accuracy >= 75
      ? kuat
      : accuracy >= 50
      ? cukup
      : lemah;

  /// Warna grafik khusus (sudah lolos uji buta warna, kontras ≥3:1, dan
  /// pita kecerahan untuk mode terang & gelap). Selalu dipasangkan dengan
  /// ikon + label, tidak pernah warna saja.
  Color color(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      kuat => dark ? const Color(0xFF2FA37D) : const Color(0xFF0E8A5F),
      cukup => dark ? const Color(0xFF4C8BDD) : const Color(0xFF2A6BBC),
      lemah => dark ? const Color(0xFFC27C28) : const Color(0xFFB5600A),
    };
  }
}

/// Target nilai: garis putus-putus di grafik = batas "Kuat".
const masteryTarget = 75.0;
