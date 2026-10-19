import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../booking/booking_repository.dart';

/// Kartu hero "sesi berikutnya" untuk home tutor.
class TutorHero extends StatelessWidget {
  const TutorHero({super.key, required this.next});

  final BookingItem? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Gradasi 2 warna bertetangga: teal brand digelapkan ke versi lebih gelap.
    // Titik terterang (kiri atas) #006F8E: putih 5.73:1, putih .9 4.98:1.
    // Mode gelap lebih redup lagi (#00566F → #003E4F).
    Color shade(double t) => Color.lerp(AppColors.primary, Colors.black, t)!;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark ? [shade(0.3), shade(0.5)] : [shade(0.1), shade(0.3)],
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: context.palette.brand.withValues(alpha: 0.24),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -52,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SESI BERIKUTNYA',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                next == null
                    ? 'Belum ada sesi berikutnya'
                    : '${next!.subjectName} ${next!.jenjang} bersama ${next!.studentName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 9),
              if (next != null)
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${AppFormat.dayLabel(next!.scheduledAt)} · ${AppFormat.timeRangeFrom(next!.scheduledAt, next!.durationMinutes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      next!.mode == 'online'
                          ? Icons.videocam_outlined
                          : Icons.place_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      next!.mode == 'online' ? 'Online' : 'Offline',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
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
        ],
      ),
    );
  }
}
