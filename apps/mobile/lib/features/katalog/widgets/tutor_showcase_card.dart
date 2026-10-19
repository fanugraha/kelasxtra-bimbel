import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';

/// Kartu tutor untuk Beranda: foto besar di atas, lalu nama, harga, dan jadwal.
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

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TutorPhoto(
              name: name,
              photoUrl: photoUrl,
              subjectLine: subjectLine,
              rating: rating,
              height: 106,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (subjectLine != null && subjectLine!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subjectLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 6),
                    _PriceLine(
                      minPrice: minPrice,
                      durationMinutes: durationMinutes,
                    ),
                    const Spacer(),
                    if (days.isNotEmpty)
                      _DayChips(days: days, maxDays: maxDays),
                    const SizedBox(height: 8),
                    const _ProfileCta(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu tutor untuk grid "Cari Tutor" — rasio produk marketplace:
/// foto di atas, informasi ringkas di bawah.
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
    this.maxDays = 2,
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
    final meta = (subjectLine != null && subjectLine!.isNotEmpty)
        ? subjectLine
        : education;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TutorPhoto(
              name: name,
              photoUrl: photoUrl,
              subjectLine: meta,
              rating: rating,
              height: 132,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 2,
                  10,
                  AppSpacing.sm + 2,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (meta == null || meta.isEmpty)
                          ? 'Tutor terverifikasi'
                          : meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.25),
                    ),
                    const Spacer(),
                    _PriceLine(
                      minPrice: minPrice,
                      durationMinutes: durationMinutes,
                      compact: true,
                    ),
                    const SizedBox(height: 6),
                    if (days.isNotEmpty)
                      _DayChips(days: days, maxDays: maxDays),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bagian foto kartu: foto asli bila ada, atau ilustrasi gradien bila kosong.
class _TutorPhoto extends StatelessWidget {
  const _TutorPhoto({
    required this.name,
    required this.photoUrl,
    required this.subjectLine,
    required this.rating,
    required this.height,
  });

  final String name;
  final String? photoUrl;
  final String? subjectLine;
  final double rating;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;
    final fallback = _PhotoFallback(name: name, subjectLine: subjectLine);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasPhoto)
            Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
              errorBuilder: (context, error, stackTrace) => fallback,
            )
          else
            fallback,
          Positioned(
            top: 8,
            left: 8,
            child: _VerifiedPill(compact: height < 120),
          ),
          Positioned(top: 8, right: 8, child: _RatingPill(rating: rating)),
        ],
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.name, required this.subjectLine});

  final String name;
  final String? subjectLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    // Gradasi teal 2 warna bertetangga, digelapkan agar teks putih kecil
    // (mapel · jenjang) lolos AA. Titik terterang #006986: putih 6.24:1, dan
    // ±5.2:1 bila tertimpa gelembung putih 12%. Mode gelap lebih redup.
    final dark = theme.brightness == Brightness.dark;
    Color shade(double t) => Color.lerp(AppColors.primary, Colors.black, t)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [shade(0.35), shade(0.55)]
              : [shade(0.15), shade(0.35)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: _Bubble(size: 104, opacity: 0.12),
          ),
          Positioned(
            left: -26,
            bottom: -36,
            child: _Bubble(size: 92, opacity: 0.08),
          ),
          Center(
            child: Icon(
              _subjectIcon(subjectLine),
              size: 86,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  initial,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    subjectLine ?? 'Tutor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _subjectIcon(String? subject) {
  final text = (subject ?? '').toLowerCase();
  if (text.contains('matematika') || text.contains('math')) {
    return Icons.functions_rounded;
  }
  if (text.contains('fisika') ||
      text.contains('kimia') ||
      text.contains('biologi') ||
      text.contains('ipa')) {
    return Icons.science_rounded;
  }
  if (text.contains('inggris') || text.contains('bahasa')) {
    return Icons.translate_rounded;
  }
  return Icons.menu_book_rounded;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pil selalu putih → teal gelap tetap (bukan scheme.primary yang di
          // mode gelap jadi terang). primaryDark di putih .94: ≥5.8:1.
          const Icon(
            Icons.verified_rounded,
            size: 12,
            color: AppColors.primaryDark,
          ),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(
              'Terverifikasi',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.star),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
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
    this.compact = false,
  });

  final int? minPrice;
  final int durationMinutes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Harga = informasi → NETRAL (onSurface), tidak bersaing dengan aksi brand.
    final priceStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    final unitStyle = theme.textTheme.labelSmall;
    if (minPrice == null) {
      return Text(
        'Harga di detail tutor',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      );
    }
    if (compact) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: AppFormat.rupiah(minPrice!), style: priceStyle),
            TextSpan(text: ' / $durationMinutes mnt', style: unitStyle),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Mulai ', style: unitStyle),
          TextSpan(text: AppFormat.rupiah(minPrice!), style: priceStyle),
          TextSpan(text: ' / $durationMinutes mnt', style: unitStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Lihat profil',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.arrow_forward_rounded, size: 13, color: primary),
        ],
      ),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
      ),
    );
  }
}
