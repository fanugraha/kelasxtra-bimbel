import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_head.dart';
import '../../bank_soal/bank_soal_providers.dart';
import '../../booking/booking_repository.dart';
import '../../katalog/katalog_providers.dart';
import '../widgets/section_head.dart';
import 'widgets/featured_tutors.dart';
import 'widgets/promo_carousel.dart';
import 'widgets/student_focus.dart';
import 'widgets/student_session_card.dart';

/// Bagian home untuk flavor siswa.
class HomeSiswaView extends ConsumerWidget {
  const HomeSiswaView({super.key, required this.upcoming});

  final List<BookingItem> upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const PromoCarousel(),
        const SizedBox(height: AppSpacing.xl),
        sidePad(
          SectionHead(
            title: 'Jadwal berikutnya',
            actionLabel: 'Semua',
            onAction: () => context.go('/jadwal'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        sidePad(
          upcoming.isEmpty
              ? AppCard(
                  onTap: () => context.go('/katalog'),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Belum ada sesi terjadwal. Yuk pilih tutor dan booking sesi pertamamu.',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                )
              : StudentSessionCard(booking: upcoming.first),
        ),
        const SizedBox(height: AppSpacing.xl),
        sidePad(
          StudentFocus(stats: ref.watch(myStatsProvider).value ?? const []),
        ),
        const SizedBox(height: AppSpacing.xl),
        FeaturedTutors(
          tutors: ref.watch(featuredTutorsProvider).value ?? const [],
        ),
      ],
    );
  }
}
