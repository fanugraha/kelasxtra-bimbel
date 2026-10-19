import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../booking/booking_repository.dart';

/// Strip 7 hari ke depan: hari ini terisi brand, hari yang ada sesi diberi
/// titik + jumlahnya. Sekilas siswa tahu minggu ini padat atau longgar.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.upcoming});

  final List<BookingItem> upcoming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 0; i < 7; i++) today.add(Duration(days: i))];
    final counts = <DateTime, int>{};
    for (final b in upcoming) {
      final d = DateTime(
        b.scheduledAt.year,
        b.scheduledAt.month,
        b.scheduledAt.day,
      );
      counts[d] = (counts[d] ?? 0) + 1;
    }
    final total = days.fold<int>(0, (s, d) => s + (counts[d] ?? 0));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  '7 hari ke depan',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  total == 0 ? 'Belum ada sesi' : '$total sesi',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: total == 0 ? null : palette.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: _Day(
                    date: d,
                    isToday: d == today,
                    count: counts[d] ?? 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.date, required this.isToday, required this.count});

  final DateTime date;
  final bool isToday;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final has = count > 0;
    final fg = isToday ? palette.onBrand : scheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isToday
            ? palette.brand
            : has
            ? palette.brandSoft
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            AppFormat.shortDayName(date.weekday % 7),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isToday
                  ? palette.onBrand.withValues(alpha: 0.85)
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${date.day}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: has
                  ? (isToday ? palette.onBrand : palette.brand)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
