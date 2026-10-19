import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/person_photo.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../booking/booking_repository.dart';

/// Kartu sesi mendatang untuk home siswa, gaya profil dokter Halodoc:
/// foto tentor di kiri, info sesi di kanan, lalu jadwal dan aksi.
class StudentSessionCard extends StatelessWidget {
  const StudentSessionCard({super.key, required this.booking});

  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final at = booking.scheduledAt;
    final online = booking.mode == 'online';

    return AppCard(
      onTap: () => context.push('/sesi/${booking.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonPhoto(
                name: booking.tutorName,
                photoUrl: booking.tutorPhotoUrl,
                subjectLine: booking.subjectName,
                size: 64,
                radius: 18,
                showVerified: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.subjectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tutor ${booking.tutorName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${booking.jenjang} · ${booking.durationMinutes} menit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        BookingBadge(status: booking.status),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              online
                                  ? Icons.videocam_outlined
                                  : Icons.place_outlined,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              online ? 'Online' : 'Offline',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  AppFormat.dateShort(at),
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${AppFormat.timeRangeFrom(at, booking.durationMinutes)} WIB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/sesi/${booking.id}'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Lihat detail sesi'),
            ),
          ),
        ],
      ),
    );
  }
}
