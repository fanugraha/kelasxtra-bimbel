import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Baris kursi visual: satu ikon per kursi.
/// - terisi (lunas)  → kursi penuh warna brand
/// - sedang dibayar  → kursi garis putus oranye + jam (≤ 5 menit, bisa kosong)
/// - tersedia        → kursi garis abu
/// Setiap status juga punya teks di legenda, tidak hanya warna.
class SeatRow extends StatelessWidget {
  const SeatRow({
    super.key,
    required this.max,
    required this.paid,
    required this.held,
    this.size = 30,
    this.mine = false,
  });

  final int max;
  final int paid;
  final int held;
  final double size;

  /// Salah satu kursi lunas adalah milik siswa ini (diberi tanda).
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < max; i++)
          if (i < paid)
            _Seat(
              size: size,
              bg: palette.brand,
              fg: palette.onBrand,
              icon: mine && i == paid - 1
                  ? Icons.person_rounded
                  : Icons.event_seat_rounded,
              border: palette.brand,
            )
          else if (i < paid + held)
            _Seat(
              size: size,
              bg: palette.warningSoft,
              fg: palette.warning,
              icon: Icons.hourglass_top_rounded,
              border: palette.warning,
            )
          else
            _Seat(
              size: size,
              bg: scheme.surface,
              fg: scheme.outlineVariant,
              icon: Icons.event_seat_outlined,
              border: scheme.outlineVariant,
            ),
      ],
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.size,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.border,
  });

  final double size;
  final Color bg;
  final Color fg;
  final IconData icon;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: border, width: 1.4),
      ),
      child: Icon(icon, size: size * 0.58, color: fg),
    );
  }
}

/// Legenda kecil di bawah baris kursi.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key, required this.held});

  final int held;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    Widget item(Color c, String t, {bool outline = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: outline ? null : c,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: c, width: 1.4),
          ),
        ),
        const SizedBox(width: 4),
        Text(t, style: theme.textTheme.labelSmall),
      ],
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(palette.brand, 'Terisi (sudah bayar)'),
        if (held > 0) item(palette.warning, 'Sedang dibayar'),
        item(scheme.outlineVariant, 'Tersedia', outline: true),
      ],
    );
  }
}
