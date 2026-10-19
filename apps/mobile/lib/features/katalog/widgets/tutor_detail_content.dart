import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/form_group.dart';
import '../../../core/widgets/screen_head.dart';
import '../katalog_repository.dart';
import 'tutor_availability_card.dart';
import 'tutor_identity_card.dart';

/// Isi halaman profil tutor: identitas, ringkasan, tentang, mapel, jadwal.
class TutorDetailContent extends StatelessWidget {
  const TutorDetailContent({super.key, required this.detail});

  final TutorDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = detail.tutor;
    final theme = Theme.of(context);
    final modes = detail.availability.map((a) => a.mode).toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        ScreenHead(
          showBack: true,
          eyebrow: 'Profil tutor',
          title: t.fullName.isEmpty ? 'Detail tutor' : t.fullName,
          subtitle: (t.education != null && t.education!.isNotEmpty)
              ? t.education!
              : t.subjectLine.isEmpty
              ? 'Kenali tutor sebelum membeli paket.'
              : t.subjectLine,
        ),
        const SizedBox(height: AppSpacing.xl),
        TutorIdentityCard(
          tutor: t,
          modes: modes,
          minPackagePrice: detail.minPackagePrice,
          minPackageSesi: detail.minPackageSesi,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _TutorStatCard(
                value: t.ratingAvg.toStringAsFixed(1),
                label: 'rating',
                icon: Icons.star_rounded,
                iconColor: context.palette.reward, // Rating = REWARD.
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _TutorStatCard(
                value: '${detail.subjects.length}',
                label: 'mapel',
                icon: Icons.menu_book_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _TutorStatCard(
                value: '${modes.length}',
                label: 'mode',
                icon: Icons.laptop_mac_rounded,
              ),
            ),
          ],
        ),
        if (t.bio != null && t.bio!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('Tentang'),
          const SizedBox(height: AppSpacing.sm),
          Text(t.bio!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle('Mapel & jenjang'),
        const SizedBox(height: AppSpacing.sm),
        if (detail.subjects.isEmpty)
          Text('Belum ada data mapel.', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final s in detail.subjects)
                _TutorPill(label: '${s.subjectName} · ${s.jenjang}'),
            ],
          ),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle('Jadwal ketersediaan'),
        const SizedBox(height: 2),
        Text(
          'Jadwal mingguan tutor. Pilih jam dan tanggal saat memesan sesi.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        if (detail.availability.isEmpty)
          Text('Belum ada jadwal.', style: theme.textTheme.bodySmall)
        else
          TutorAvailabilityCard(slots: detail.availability),
      ],
    );
  }
}

/// Pill data (mapel · jenjang) — bentuk sama dengan chip katalog, tanpa aksi.
class _TutorPill extends StatelessWidget {
  const _TutorPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }
}

class _TutorStatCard extends StatelessWidget {
  const _TutorStatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: 10,
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: iconColor ?? theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
