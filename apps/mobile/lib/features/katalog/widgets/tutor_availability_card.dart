import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../katalog_repository.dart';

/// Jadwal mingguan dikelompokkan per hari supaya tidak jadi daftar panjang.
class TutorAvailabilityCard extends StatelessWidget {
  const TutorAvailabilityCard({super.key, required this.slots});

  final List<TutorAvailabilityItem> slots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = <int, List<TutorAvailabilityItem>>{};
    for (final s in slots) {
      byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
    }
    final days = byDay.keys.toList()
      ..sort((a, b) => (a == 0 ? 7 : a).compareTo(b == 0 ? 7 : b));

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: theme.colorScheme.outline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 78,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        AppFormat.longDayName(days[i]),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in byDay[days[i]]!) _TutorSlotChip(slot: s),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TutorSlotChip extends StatelessWidget {
  const _TutorSlotChip({required this.slot});

  final TutorAvailabilityItem slot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = slot.mode == 'online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.videocam_outlined : Icons.place_outlined,
            size: 13,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            slot.timeRange,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
