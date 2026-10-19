import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../jadwal_grouping.dart';

/// Tiga kotak angka tonal: sesi mendatang, sesi selesai, jam belajar.
class StatTiles extends StatelessWidget {
  const StatTiles({super.key, required this.person});

  final JadwalPerson person;

  static String _hours(double h) {
    if (h == h.roundToDouble()) return h.toInt().toString();
    return h.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.event_rounded,
            value: '${person.upcoming.length}',
            label: 'Akan datang',
            bg: palette.infoSoft,
            fg: palette.info,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: _Tile(
            icon: Icons.task_alt_rounded,
            value: '${person.completedCount}',
            label: 'Selesai',
            bg: palette.challengeSoft,
            fg: palette.challenge,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: _Tile(
            icon: Icons.timer_outlined,
            value: _hours(person.completedHours),
            label: 'Jam belajar',
            bg: palette.rewardSoft,
            fg: palette.reward,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.value,
    required this.label,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
