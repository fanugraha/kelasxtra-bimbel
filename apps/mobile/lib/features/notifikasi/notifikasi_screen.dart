import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import 'notifikasi_providers.dart';
import 'notifikasi_repository.dart';

class NotifikasiScreen extends ConsumerWidget {
  const NotifikasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: AsyncView<List<AppNotification>>(
        value: items,
        errorTitle: 'Gagal memuat notifikasi',
        onRetry: () => ref.invalidate(myNotificationsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Belum ada notifikasi',
              message: 'Info sesi, pembayaran, dan payroll akan muncul di sini.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myNotificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (c, i) => _NotifCard(item: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotifCard extends ConsumerWidget {
  const _NotifCard({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: item.read
          ? null
          : () async {
              await ref.read(notificationRepositoryProvider).markRead(item.id);
              ref.invalidate(myNotificationsProvider);
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
              if (!item.read)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(item.body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppFormat.dateTimeShort(item.createdAt),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
