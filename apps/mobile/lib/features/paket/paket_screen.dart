import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_head.dart';
import '../../widgets/status_badge.dart';
import 'paket_providers.dart';
import 'paket_repository.dart';

class PaketScreen extends ConsumerWidget {
  const PaketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(myPackagesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(myPackagesProvider),
          child: ListView(
            padding: screenPadding,
            children: [
              const ScreenHead(
                showBack: true,
                eyebrow: 'Kuota belajar',
                title: 'Paket Saya',
                subtitle:
                    'Kuota terikat ke tutor, mapel, dan durasi yang sama.',
              ),
              const SizedBox(height: 18),
              AsyncView<List<PackageItem>>(
                value: packages,
                errorTitle: 'Gagal memuat paket',
                onRetry: () => ref.invalidate(myPackagesProvider),
                builder: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Icons.card_membership_rounded,
                        title: 'Belum ada paket',
                        message: 'Beli paket sesi untuk hemat hingga 10%.',
                        action: FilledButton.icon(
                          onPressed: () => context.go('/katalog'),
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Cari Tutor'),
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in list) ...[
                            _PackageCard(item: item),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/katalog'),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Tambah kuota dari tutor'),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.item});

  final PackageItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sisa = item.sisaSesi;
    final progress = item.totalSesi == 0 ? 0.0 : sisa / item.totalSesi;
    final tone = item.aktif
        ? StatusTone.success
        : item.status == 'pending_payment'
            ? StatusTone.warning
            : StatusTone.neutral;

    return AppCard(
      onTap: () => context.push('/tutor/${item.tutorId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(label: item.statusLabel, tone: tone),
              const Spacer(),
              Text(
                '#${item.id.substring(0, 6).toUpperCase()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 9.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.11),
                child: Text(
                  (item.tutorName ?? 'T').isEmpty
                      ? 'T'
                      : item.tutorName![0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.tutorName ?? 'Tutor',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${item.subjectName ?? '-'} · ${item.jenjang} · ${item.durationMinutes} menit',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Text('Sisa sesi',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
              const Spacer(),
              Text('$sisa / ${item.totalSesi}',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: theme.colorScheme.outline,
              valueColor: AlwaysStoppedAnimation(
                progress >= 0.8
                    ? AppColors.success
                    : progress <= 0
                        ? AppColors.warning
                        : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            item.expiresAt == null
                ? 'Tanpa batas waktu'
                : 'Berlaku sampai ${AppFormat.dateShort(item.expiresAt!)}. Pindah tutor harus disetujui siswa.',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: item.aktif
                      ? () => context.push('/booking/${item.tutorId}')
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    textStyle: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Pesan sesi'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/tutor/${item.tutorId}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    textStyle: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Lihat tutor'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
