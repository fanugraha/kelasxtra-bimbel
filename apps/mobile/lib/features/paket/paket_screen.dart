import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import 'paket_providers.dart';
import 'paket_repository.dart';

class PaketScreen extends ConsumerWidget {
  const PaketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(myPackagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paket Saya')),
      body: AsyncView<List<PackageItem>>(
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
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(myPackagesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (c, i) => _PackageCard(item: list[i]),
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
    final progress = item.totalSesi == 0 ? 0.0 : item.sesiTerpakai / item.totalSesi;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.tutorName ?? 'Tutor', style: theme.textTheme.titleMedium),
              ),
              _StatusChip(label: item.statusLabel, aktif: item.aktif),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${item.subjectName ?? '-'} · ${item.jenjang} · ${item.durationMinutes} menit · '
            '${item.mode == 'online' ? 'Online' : 'Offline'}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('$sisa dari ${item.totalSesi} sesi tersisa',
                  style: theme.textTheme.bodyMedium),
              const Spacer(),
              if (item.discountPercent > 0)
                Text('hemat ${item.discountPercent}%',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
          if (item.expiresAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Berlaku s/d ${AppFormat.dateShort(item.expiresAt!)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.aktif});

  final String label;
  final bool aktif;

  @override
  Widget build(BuildContext context) {
    final color = aktif ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
