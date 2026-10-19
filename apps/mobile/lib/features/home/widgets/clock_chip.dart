import 'package:flutter/material.dart';

import '../../../core/format.dart';

/// Chip jam ringkas: hari, jam, dan durasi. Dipakai kartu sesi home.
class ClockChip extends StatelessWidget {
  const ClockChip({super.key, required this.date, required this.minutes});

  final DateTime date;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            AppFormat.dayLabel(date),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppFormat.hm(date),
            style: TextStyle(
              fontSize: 17,
              height: 1,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$minutes mnt',
            style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
