import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../booking/booking_repository.dart';
import '../../widgets/clock_chip.dart';

/// Kartu sesi terdekat untuk home tutor.
class TutorSessionCard extends StatelessWidget {
  const TutorSessionCard({super.key, required this.booking});

  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/sesi/${booking.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
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
                    Text(
                      '${booking.subjectName} · ${booking.studentName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.jenjang} · ${booking.durationMinutes} menit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              BookingBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 10),
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
