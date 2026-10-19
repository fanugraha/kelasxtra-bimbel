import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../booking/booking_repository.dart';
import '../../widgets/clock_chip.dart';

/// Kartu sesi mendatang untuk home siswa.
class StudentSessionCard extends StatelessWidget {
  const StudentSessionCard({super.key, required this.booking});

  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/sesi/${booking.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClockChip(
                date: booking.scheduledAt,
                minutes: booking.durationMinutes,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.tutorName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.subjectName} · ${booking.jenjang} · ${booking.durationMinutes} menit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    BookingBadge(status: booking.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                booking.mode == 'online'
                    ? Icons.videocam_outlined
                    : Icons.place_outlined,
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                booking.mode == 'online' ? 'Online' : 'Offline',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.schedule_rounded, size: 16),
              const SizedBox(width: 5),
              Text(
                '${AppFormat.timeRangeFrom(booking.scheduledAt, booking.durationMinutes)} WIB',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/sesi/${booking.id}'),
              child: const Text('Detail sesi'),
            ),
          ),
        ],
      ),
    );
  }
}
