import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/screen_head.dart';
import '../../../katalog/katalog_repository.dart';
import '../../../katalog/widgets/tutor_showcase_card.dart';
import '../../widgets/section_head.dart';

/// Deretan tutor pilihan (horizontal) untuk home siswa.
class FeaturedTutors extends StatelessWidget {
  const FeaturedTutors({super.key, required this.tutors});

  final List<TutorCatalogItem> tutors;

  @override
  Widget build(BuildContext context) {
    if (tutors.isEmpty) return const SizedBox.shrink();
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    // 270: ruang untuk mapel (bodySmall 14) & harga titleMedium setelah
    // tipografi dinaikkan dari 11/15.
    final cardHeight = 270 + (textScale - 1).clamp(0.0, 1.2) * 130;
    return Column(
      children: [
        sidePad(
          SectionHead(
            title: 'Tutor pilihan',
            actionLabel: 'Lihat semua',
            onAction: () => context.go('/katalog'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tutors.take(6).length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final t = tutors[i];
              return SizedBox(
                width: 220,
                child: TutorShowcaseCard(
                  name: t.fullName,
                  rating: t.ratingAvg,
                  subjectLine: t.subjectLine,
                  days: t.dayLabels,
                  photoUrl: t.photoUrl,
                  minPrice: t.minPrice,
                  onTap: () => context.push('/tutor/${t.id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
