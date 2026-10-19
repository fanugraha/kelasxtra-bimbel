import 'package:flutter/material.dart';

import '../../../core/format.dart';

/// Chip jam ringkas: hari, jam, dan durasi. Dipakai kartu sesi home.
class ClockChip extends StatelessWidget {
  const ClockChip({super.key, required this.date, required this.minutes});

  final DateTime date;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Latar netral: tanggal & jam = informasi, bukan ajakan (bukan brand).
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            AppFormat.dayLabel(date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          // Warna: angka jam netral — informasi, bukan ajakan.
          Text(
            AppFormat.hm(date),
            maxLines: 1,
            style: theme.textTheme.titleLarge?.copyWith(
              height: 1.1,
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text('$minutes mnt', maxLines: 1, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
