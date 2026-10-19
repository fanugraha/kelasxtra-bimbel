import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../katalog_providers.dart';
import '../katalog_repository.dart';

/// Wadah satu bagian profil: kartu dengan kepala seragam (ikon tonal +
/// judul + keterangan kanan) supaya siswa yang menggulir tahu persis sedang
/// membaca bagian apa.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
        border: Border.all(color: scheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 19, color: palette.brand),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: scheme.outline),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Keterangan kecil di kanan kepala bagian, mis. "4 hari" atau "★ 4,8".
class SectionTag extends StatelessWidget {
  const SectionTag({super.key, required this.text, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final fg = color ?? palette.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Tentang ───────────────────────────

class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.tutor});

  final TutorCatalogItem tutor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bio = tutor.bio?.trim();
    final edu = tutor.education?.trim();
    final hasBio = bio != null && bio.isNotEmpty;
    final hasEdu = edu != null && edu.isNotEmpty;

    return ProfileSection(
      icon: Icons.person_rounded,
      title: 'Tentang tutor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasBio ? bio : 'Tutor belum menulis perkenalan.',
            style: hasBio
                ? theme.textTheme.bodyMedium?.copyWith(height: 1.55)
                : theme.textTheme.bodySmall,
          ),
          if (hasEdu) ...[
            const SizedBox(height: AppSpacing.md),
            _Tile(icon: Icons.school_rounded, label: 'Pendidikan', value: edu),
          ],
        ],
      ),
    );
  }
}

/// Baris keterangan berlatar tonal tipis (label kecil + isi tebal).
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.brand),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                Text(value, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Mapel ───────────────────────────

class SubjectsSection extends StatelessWidget {
  const SubjectsSection({super.key, required this.subjects});

  final List<TutorSubjectItem> subjects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final bySubject = <String, List<String>>{};
    for (final s in subjects) {
      bySubject.putIfAbsent(s.subjectName, () => []).add(s.jenjang);
    }
    final entries = bySubject.entries.toList();

    return ProfileSection(
      icon: Icons.menu_book_rounded,
      title: 'Mapel & jenjang',
      trailing: entries.isEmpty
          ? null
          : SectionTag(text: '${entries.length} mapel'),
      child: entries.isEmpty
          ? Text('Belum ada data mapel.', style: theme.textTheme.bodySmall)
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    Divider(height: AppSpacing.lg, color: scheme.outline),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entries[i].key,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final j in entries[i].value)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: palette.brandSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                j,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: palette.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

// ─────────────────────────── Jadwal ───────────────────────────

/// Jadwal mingguan: satu baris per hari, urut dari hari ini ke depan.
/// Hari tersedia terdekat diberi warna penuh.
class ScheduleSection extends StatelessWidget {
  const ScheduleSection({super.key, required this.slots});

  final List<TutorAvailabilityItem> slots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = <int, List<TutorAvailabilityItem>>{};
    for (final s in slots) {
      byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    // 0 = Minggu. Urut dari hari ini ke depan, jadi baris pertama = terdekat.
    final today = DateTime.now().weekday % 7;
    final days = byDay.keys.toList()
      ..sort((a, b) => ((a - today) % 7).compareTo((b - today) % 7));

    return ProfileSection(
      icon: Icons.calendar_month_rounded,
      title: 'Jadwal mingguan',
      subtitle: 'Jam persisnya dipilih saat membeli paket',
      trailing: days.isEmpty ? null : SectionTag(text: '${days.length} hari'),
      child: days.isEmpty
          ? Text(
              'Tutor belum mengatur jadwal mingguan.',
              style: theme.textTheme.bodySmall,
            )
          : Column(
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _DayRow(
                    day: days[i],
                    slots: byDay[days[i]]!,
                    isToday: days[i] == today,
                    highlight: i == 0,
                  ),
                ],
              ],
            ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.slots,
    required this.isToday,
    required this.highlight,
  });

  final int day;
  final List<TutorAvailabilityItem> slots;
  final bool isToday;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final fg = highlight ? palette.onBrand : scheme.onSurface;
    final sub = highlight
        ? palette.onBrand.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final modes = slots.map((s) => s.mode).toSet();
    final modeLabel = modes.length > 1
        ? 'Online & Offline'
        : modes.first == 'online'
        ? 'Online'
        : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: highlight ? palette.brand : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlight
                  ? palette.onBrand.withValues(alpha: 0.9)
                  : palette.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              modes.length == 1 && modes.first == 'offline'
                  ? Icons.place_rounded
                  : Icons.videocam_rounded,
              size: 18,
              color: palette.brand,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday
                      ? '${AppFormat.longDayName(day)} · Hari ini'
                      : AppFormat.longDayName(day),
                  style: theme.textTheme.titleSmall?.copyWith(color: fg),
                ),
                const SizedBox(height: 1),
                Text(
                  '${slots.length} slot · $modeLabel',
                  style: theme.textTheme.bodySmall?.copyWith(color: sub),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final s in slots)
                Text(
                  s.timeRange,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Ulasan ───────────────────────────

/// Ulasan siswa: ringkasan rating, lalu 3 ulasan terbaru; sisanya dibuka
/// lewat "Lihat semua". Penulis tampil anonim — data siswa lain tertutup.
class ReviewsSection extends ConsumerStatefulWidget {
  const ReviewsSection({super.key, required this.tutor});

  final TutorCatalogItem tutor;

  @override
  ConsumerState<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<ReviewsSection> {
  static const _preview = 3;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final t = widget.tutor;
    final reviews = ref.watch(tutorReviewsProvider(t.id));
    final count = reviews.value?.length ?? 0;

    return ProfileSection(
      icon: Icons.reviews_rounded,
      title: 'Ulasan siswa',
      trailing: count == 0
          ? null
          : SectionTag(
              icon: Icons.star_rounded,
              text: t.ratingAvg.toStringAsFixed(1).replaceAll('.', ','),
              color: palette.reward,
            ),
      child: AsyncView<List<TutorReview>>(
        value: reviews,
        errorTitle: 'Gagal memuat ulasan',
        onRetry: () => ref.invalidate(tutorReviewsProvider(t.id)),
        builder: (list) {
          if (list.isEmpty) {
            return Text(
              'Belum ada ulasan. Ulasan muncul setelah siswa menyelesaikan sesi.',
              style: theme.textTheme.bodySmall,
            );
          }
          final shown = _expanded ? list : list.take(_preview).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReviewSummary(avg: t.ratingAvg, reviews: list),
              for (final r in shown) ...[
                Divider(height: AppSpacing.xl, color: scheme.outline),
                _ReviewItem(review: r),
              ],
              if (list.length > _preview) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded
                        ? 'Tampilkan lebih sedikit'
                        : 'Lihat semua ${list.length} ulasan',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.avg, required this.reviews});

  final double avg;
  final List<TutorReview> reviews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final counts = List.filled(6, 0);
    for (final r in reviews) {
      counts[r.rating.clamp(1, 5)]++;
    }
    final total = reviews.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: palette.rewardSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1).replaceAll('.', ','),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              _Stars(rating: avg.round(), size: 14),
              const SizedBox(height: 4),
              Text('$total ulasan terbaru', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text(
                            '$star',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : counts[star] / total,
                              minHeight: 6,
                              color: palette.reward,
                              backgroundColor: scheme.surface,
                            ),
                          ),
                        ),
                      ],
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

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review});

  final TutorReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final comment = review.comment?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_rounded, size: 17, color: palette.brand),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Siswa', style: theme.textTheme.titleSmall),
                  Text(
                    AppFormat.dateNumber(review.createdAt),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            _Stars(rating: review.rating, size: 15),
          ],
        ),
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            comment,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.size});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= rating ? palette.reward : scheme.outlineVariant,
          ),
      ],
    );
  }
}
