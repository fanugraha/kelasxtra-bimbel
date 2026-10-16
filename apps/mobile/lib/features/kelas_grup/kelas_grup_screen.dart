import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import 'kelas_grup_providers.dart';
import 'kelas_grup_repository.dart';

class KelasGrupScreen extends ConsumerWidget {
  const KelasGrupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(groupClassesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelas Grup')),
      body: AsyncView<List<GroupClassItem>>(
        value: classes,
        errorTitle: 'Gagal memuat kelas grup',
        onRetry: () => ref.invalidate(groupClassesProvider),
        builder: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.groups_rounded,
                title: 'Belum ada kelas grup',
                message: 'Kelas grup akan muncul di sini saat admin membukanya.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(groupClassesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (c, i) => _ClassCard(item: list[i]),
                ),
              ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item});

  final GroupClassItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jadwal = (item.firstSession != null && item.lastSession != null)
        ? '${AppFormat.dateTimeShort(item.firstSession!)}'
            '  →  ${AppFormat.dateShort(item.lastSession!)}'
        : '—';

    return AppCard(
      onTap: () => context.push('/kelas-grup/${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.tutorName ?? 'Tutor',
                    style: theme.textTheme.titleMedium),
              ),
              _Chip(
                label: item.dibuka ? 'Dibuka' : 'Jalan',
                color: item.dibuka ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${item.subjectName ?? '-'} · ${item.jenjang} · ${item.durationMinutes} menit · '
            '${item.mode == 'online' ? 'Online' : 'Offline'}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.event_repeat_rounded, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(jadwal, style: theme.textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.airline_seat_recline_normal_rounded, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text('${item.seatsTaken}/${item.maxSeats} kursi',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(width: AppSpacing.sm),
              Text('· minimal ${item.minSeats}', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(
                AppFormat.rupiah(item.priceTotal),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          if (item.discountPercent > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${item.totalSesi} sesi · hemat ${item.discountPercent}%',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.success)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
