import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_head.dart';
import '../../absensi_grup/absensi_grup_providers.dart';
import '../../booking/booking_repository.dart';
import '../../penghasilan/penghasilan_providers.dart';
import '../widgets/section_head.dart';
import 'widgets/tutor_group_card.dart';
import 'widgets/tutor_hero.dart';
import 'widgets/tutor_session_card.dart';
import 'widgets/tutor_stats.dart';

/// Bagian home untuk flavor tutor.
class HomeTutorView extends ConsumerWidget {
  const HomeTutorView({
    super.key,
    required this.bookings,
    required this.upcoming,
  });

  final List<BookingItem> bookings;
  final List<BookingItem> upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        sidePad(TutorHero(next: upcoming.isEmpty ? null : upcoming.first)),
        const SizedBox(height: AppSpacing.md),
        sidePad(
          TutorStats(
            bookings: bookings,
            payouts: ref.watch(myPayoutsProvider).value ?? const [],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        sidePad(
          SectionHead(
            title: 'Jadwal terdekat',
            actionLabel: 'Semua',
            onAction: () => context.go('/jadwal'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (upcoming.isEmpty)
          sidePad(const AppCard(child: Text('Belum ada sesi terjadwal.')))
        else
          for (final b in upcoming.take(2)) ...[
            sidePad(TutorSessionCard(booking: b)),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.xl),
        sidePad(
          SectionHead(
            title: 'Kelas grup',
            actionLabel: 'Absensi',
            onAction: () => context.go('/absensi-grup'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        sidePad(
          TutorGroupCard(
            rows: ref.watch(groupAttendanceProvider).value ?? const [],
          ),
        ),
      ],
    );
  }
}
