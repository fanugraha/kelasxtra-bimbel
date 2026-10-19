import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../absensi_grup/absensi_grup_repository.dart';
import '../../widgets/clock_chip.dart';

/// Kartu ringkas kelas grup tutor yang butuh absensi.
class TutorGroupCard extends StatelessWidget {
  const TutorGroupCard({super.key, required this.rows});

  final List<GroupAttendanceRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return const AppCard(child: Text('Belum ada kelas grup yang kamu ampu.'));
    }
    final first = rows.first;
    final sessionRows = rows
        .where((r) => r.sessionId == first.sessionId)
        .toList();
    return AppCard(
      onTap: () => context.go('/absensi-grup'),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClockChip(date: first.scheduledAt, minutes: 90),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(first.subjectName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${sessionRows.length} siswa · ${first.mode == 'online' ? 'Online' : 'Offline'}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const StatusBadge(
                label: 'Perlu absensi',
                tone: StatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/absensi-grup'),
              child: const Text('Buka absensi'),
            ),
          ),
        ],
      ),
    );
  }
}
