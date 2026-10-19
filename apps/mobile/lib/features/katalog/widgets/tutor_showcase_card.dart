import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';

/// Kartu tutor untuk Beranda: nama, harga "mulai dari", mapel + jenjang, rating,
/// dan hari tersedia — sinyal yang dibutuhkan siswa sebelum membuka profil.
class TutorShowcaseCard extends StatelessWidget {
  const TutorShowcaseCard({
    super.key,
    required this.name,
    required this.rating,
    this.subjectLine,
    this.days = const [],
    this.photoUrl,
    this.minPrice,
    this.durationMinutes = 60,
    this.maxDays = 3,
    this.onTap,
  });

  final String name;
  final double rating;
  final String? subjectLine;
  final List<String> days;
  final String? photoUrl;
  final int? minPrice;
  final int durationMinutes;
  final int maxDays;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = subjectLine;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TutorAvatar(name: name, photoUrl: photoUrl, radius: 21),
              const Spacer(),
              _RatingPill(rating: rating),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (meta != null && meta.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _PriceLine(
            minPrice: minPrice,
            durationMinutes: durationMinutes,
            priceSize: 14.5,
            unitSize: 10,
          ),
          const Spacer(),
          if (days.isNotEmpty) _DayChips(days: days, maxDays: maxDays),
          const SizedBox(height: AppSpacing.sm),
          const _ProfileCta(),
        ],
      ),
    );
  }
}

/// Kartu tutor bentuk penuh untuk daftar "Cari Tutor". Informasinya sama
/// dengan [TutorShowcaseCard], tapi disusun mendatar agar enak dipindai dari
/// atas ke bawah (identitas → yang diajar → harga & jadwal → aksi).
class TutorListCard extends StatelessWidget {
  const TutorListCard({
    super.key,
    required this.name,
    required this.rating,
    this.education,
    this.subjectLine,
    this.days = const [],
    this.photoUrl,
    this.minPrice,
    this.durationMinutes = 60,
    this.maxDays = 4,
    this.onTap,
  });

  final String name;
  final double rating;
  final String? education;
  final String? subjectLine;
  final List<String> days;
  final String? photoUrl;
  final int? minPrice;
  final int durationMinutes;
  final int maxDays;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = subjectLine;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TutorAvatar(name: name, photoUrl: photoUrl, radius: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _RatingPill(rating: rating),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (education == null || education!.isEmpty)
                          ? 'Tutor terverifikasi'
                          : education!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (meta != null && meta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _PriceLine(
            minPrice: minPrice,
            durationMinutes: durationMinutes,
            priceSize: 15,
            unitSize: 10,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Expanded(child: _DayChips(days: days, maxDays: maxDays)),
              const SizedBox(width: AppSpacing.sm),
              const _ProfileCta(),
            ],
          ),
        ],
      ),
    );
  }
}

class _TutorAvatar extends StatelessWidget {
  const _TutorAvatar({
    required this.name,
    required this.photoUrl,
    required this.radius,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withValues(alpha: 0.11),
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.667,
              ),
            ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.star.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppColors.star),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.minPrice,
    required this.durationMinutes,
    required this.priceSize,
    required this.unitSize,
  });

  final int? minPrice;
  final int durationMinutes;
  final double priceSize;
  final double unitSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (minPrice == null) {
      return Text(
        'Harga di detail tutor',
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('Mulai ', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
        Text(
          AppFormat.rupiah(minPrice!),
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: priceSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '/ $durationMinutes mnt',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: unitSize),
        ),
      ],
    );
  }
}

class _DayChips extends StatelessWidget {
  const _DayChips({required this.days, required this.maxDays});

  final List<String> days;
  final int maxDays;

  @override
  Widget build(BuildContext context) {
    final visible = days.take(maxDays).toList();
    final more = days.length - visible.length;
    if (visible.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (final day in visible) ...[
          _DayChip(label: day),
          const SizedBox(width: AppSpacing.xs),
        ],
        if (more > 0)
          Text(
            '+$more',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _ProfileCta extends StatelessWidget {
  const _ProfileCta();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Lihat profil',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: primary,
          ),
        ),
        const SizedBox(width: 3),
        Icon(Icons.arrow_forward_rounded, size: 13, color: primary),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}
