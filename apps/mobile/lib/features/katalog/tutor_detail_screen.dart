import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import 'katalog_providers.dart';
import 'katalog_repository.dart';

class TutorDetailScreen extends ConsumerWidget {
  const TutorDetailScreen({super.key, required this.tutorId});

  final String tutorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tutorDetailProvider(tutorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Tutor')),
      bottomNavigationBar: detail.maybeWhen(
        data: (d) => d == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: AppButton(
                  label: 'Pesan Sesi',
                  icon: Icons.event_available_rounded,
                  onPressed: () => context.push('/booking/$tutorId'),
                ),
              ),
        orElse: () => null,
      ),
      body: AsyncView<TutorDetail?>(
        value: detail,
        errorTitle: 'Gagal memuat profil',
        onRetry: () => ref.invalidate(tutorDetailProvider(tutorId)),
        builder: (d) => d == null
            ? const EmptyState(
                icon: Icons.person_off_rounded,
                title: 'Tutor tidak ditemukan',
              )
            : _Content(detail: d),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail});

  final TutorDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = detail.tutor;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            backgroundImage: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                ? NetworkImage(t.photoUrl!)
                : null,
            child: (t.photoUrl == null || t.photoUrl!.isEmpty)
                ? Text(
                    t.fullName.isEmpty ? '?' : t.fullName[0].toUpperCase(),
                    style: theme.textTheme.displaySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(child: Text(t.fullName, style: theme.textTheme.titleLarge)),
        if (t.education != null && t.education!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Center(child: Text(t.education!, style: theme.textTheme.bodySmall)),
        ],
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 20, color: AppColors.star),
              const SizedBox(width: AppSpacing.xs),
              Text(
                t.ratingAvg.toStringAsFixed(1),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
        if (t.bio != null && t.bio!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle('Tentang'),
          const SizedBox(height: AppSpacing.sm),
          Text(t.bio!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.xl),
        _SectionTitle('Mapel & Jenjang'),
        const SizedBox(height: AppSpacing.sm),
        if (detail.subjects.isEmpty)
          Text('Belum ada data mapel.', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in detail.subjects)
                Chip(label: Text('${s.subjectName} · ${s.jenjang}')),
            ],
          ),
        const SizedBox(height: AppSpacing.xl),
        _SectionTitle('Jadwal Ketersediaan'),
        const SizedBox(height: AppSpacing.sm),
        if (detail.availability.isEmpty)
          Text('Belum ada jadwal.', style: theme.textTheme.bodySmall)
        else
          Column(
            children: [
              for (final a in detail.availability)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    a.mode == 'online' ? Icons.videocam_rounded : Icons.place_rounded,
                  ),
                  title: Text(a.dayName),
                  subtitle: Text(a.timeRange),
                  trailing: Text(a.mode == 'online' ? 'Online' : 'Offline'),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}
