import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';
import '../../booking/booking_repository.dart';

/// Satu baris sesi di detail kelas: kotak tanggal tonal di kiri, mapel +
/// jam di tengah, lencana status di kanan (centang penuh bila selesai).
class LessonTile extends StatelessWidget {
  const LessonTile({super.key, required this.booking, required this.onTap});

  final BookingItem booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final at = booking.scheduledAt;
    final done = booking.status == 'completed';
    final closed =
        done || booking.status == 'cancelled' || booking.status == 'refunded';
    final plain = done || booking.status == 'confirmed';
    final online = booking.mode == 'online';

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: closed
                      ? scheme.surfaceContainerHigh
                      : palette.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${at.day}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        color: closed ? scheme.onSurfaceVariant : palette.brand,
                      ),
                    ),
                    Text(
                      AppFormat.monthShort(at),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: closed ? scheme.onSurfaceVariant : palette.brand,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.subjectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${AppFormat.dayLabel(at)} · '
                      '${AppFormat.timeRangeFrom(at, booking.durationMinutes)}'
                      ' · ${online ? 'Online' : 'Offline'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (!plain) ...[
                      const SizedBox(height: 5),
                      BookingBadge(status: booking.status),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                done ? Icons.verified_rounded : Icons.verified_outlined,
                size: 24,
                color: done ? palette.challenge : scheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
