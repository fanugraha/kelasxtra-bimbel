import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../booking/booking_repository.dart';

/// Kartu hero "sesi berikutnya" untuk home tutor.
class TutorHero extends StatelessWidget {
  const TutorHero({super.key, required this.next});

  final BookingItem? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SESI BERIKUTNYA',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            next == null
                ? 'Belum ada sesi berikutnya'
                : '${next!.subjectName} ${next!.jenjang} bersama ${next!.studentName}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontSize: 24,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 9),
          if (next != null)
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: Colors.white70,
                ),
                const SizedBox(width: 5),
                Text(
                  '${AppFormat.dayLabel(next!.scheduledAt)} · ${AppFormat.timeRangeFrom(next!.scheduledAt, next!.durationMinutes)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  next!.mode == 'online'
                      ? Icons.videocam_outlined
                      : Icons.place_outlined,
                  size: 15,
                  color: Colors.white70,
                ),
                const SizedBox(width: 5),
                Text(
                  next!.mode == 'online' ? 'Online' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: () => context.go('/jadwal'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Lihat jadwal'),
          ),
        ],
      ),
    );
  }
}
