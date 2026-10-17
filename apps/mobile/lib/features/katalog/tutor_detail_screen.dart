import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_head.dart';
import '../../widgets/status_badge.dart';
import 'katalog_providers.dart';
import 'katalog_repository.dart';

class TutorDetailScreen extends ConsumerWidget {
  const TutorDetailScreen({super.key, required this.tutorId});

  final String tutorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tutorDetailProvider(tutorId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<TutorDetail?>(
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
      ),
      bottomNavigationBar: detail.maybeWhen(
        data: (d) => d == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Beli Paket',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => context.push('/paket/beli/$tutorId'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: 'Pesan Sesi',
                        icon: Icons.event_available_rounded,
                        onPressed: () => context.push('/booking/$tutorId'),
                      ),
                    ),
                  ],
                ),
              ),
        orElse: () => null,
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
    final initial = t.fullName.isEmpty ? '?' : t.fullName[0].toUpperCase();
    final modes = detail.availability.map((a) => a.mode).toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        const ScreenHead(
          showBack: true,
          eyebrow: 'Profil tutor',
          title: 'Detail tutor',
          subtitle: 'Kenali tutor sebelum memesan sesi.',
        ),
        const SizedBox(height: 18),
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                backgroundImage:
                    (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                        ? NetworkImage(t.photoUrl!)
                        : null,
                child: (t.photoUrl == null || t.photoUrl!.isEmpty)
                    ? Text(initial,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ))
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.fullName,
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                    if (t.education != null) ...[
                      const SizedBox(height: 2),
                      Text(t.education!, style: theme.textTheme.bodySmall),
                    ],
                    if (detail.subjects.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      StatusBadge(
                        label: detail.subjects.first.subjectName,
                        tone: StatusTone.info,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: t.ratingAvg.toStringAsFixed(1),
                label: 'rating',
                icon: Icons.star_rounded,
                iconColor: AppColors.star,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                value: '${detail.subjects.length}',
                label: 'mapel',
                icon: Icons.menu_book_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                value: modes.contains('online') && modes.contains('offline')
                    ? '2'
                    : '1',
                label: 'mode',
                icon: Icons.laptop_mac_rounded,
              ),
            ),
          ],
        ),
        if (t.bio != null && t.bio!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Tentang',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 17)),
          const SizedBox(height: 8),
          Text(t.bio!, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
        ],
        const SizedBox(height: 20),
        Text('Mapel & jenjang',
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 17)),
        const SizedBox(height: 9),
        if (detail.subjects.isEmpty)
          Text('Belum ada data mapel.', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final s in detail.subjects)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${s.subjectName} · ${s.jenjang}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Text('Jadwal ketersediaan',
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 17)),
        const SizedBox(height: 9),
        if (detail.availability.isEmpty)
          Text('Belum ada jadwal.', style: theme.textTheme.bodySmall)
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < detail.availability.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(
                              top: BorderSide(color: theme.colorScheme.outline)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          detail.availability[i].mode == 'online'
                              ? Icons.videocam_outlined
                              : Icons.place_outlined,
                          size: 19,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(detail.availability[i].dayName,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        Text(
                          '${detail.availability[i].timeRange} · ${detail.availability[i].mode == 'online' ? 'Online' : 'Offline'}',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
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
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, size: 17, color: iconColor ?? theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 17)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
        ],
      ),
    );
  }
}
