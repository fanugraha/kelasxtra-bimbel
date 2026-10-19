import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../chat/chat_providers.dart';
import 'notifikasi_providers.dart';
import 'notifikasi_repository.dart';

class NotifikasiScreen extends ConsumerStatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  ConsumerState<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends ConsumerState<NotifikasiScreen> {
  @override
  void initState() {
    super.initState();
    // Selalu ambil yang terbaru saat layar dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(myNotificationsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(myNotificationsProvider);

    return Scaffold(
      body: SafeArea(
        child: AsyncView<List<AppNotification>>(
        value: items,
        errorTitle: 'Gagal memuat notifikasi',
        onRetry: () => ref.invalidate(myNotificationsProvider),
        builder: (list) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myNotificationsProvider),
            child: ListView(
              padding: screenPadding,
              children: [
                const ScreenHead(
                  showBack: true,
                  eyebrow: 'Pesan masuk',
                  title: 'Notifikasi',
                  subtitle: 'Informasi sesi, pembayaran, dan aktivitas belajar.',
                ),
                const SizedBox(height: 18),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Belum ada notifikasi',
                      message:
                          'Info sesi, pembayaran, dan payroll akan muncul di sini.',
                    ),
                  )
                else
                  for (final item in list) ...[
                    _NotifCard(item: item),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          );
        },
        ),
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
      onTap: () => _open(context, ref),
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
          Row(
            children: [
              Text(
                AppFormat.dateTimeShort(item.createdAt),
                style: theme.textTheme.labelSmall,
              ),
              if (item.isChat) ...[
                const SizedBox(width: 6),
                Text(
                  '· Ketuk untuk membalas',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Tandai terbaca, lalu buka ruang chat bila ini notifikasi pesan.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(notificationRepositoryProvider);
    if (!item.read) {
      await repo.markRead(item.id);
      ref.invalidate(myNotificationsProvider);
    }

    final conversationId = item.conversationId;
    if (conversationId == null || !context.mounted) return;

    final peer = await ref
        .read(chatRepositoryProvider)
        .fetchPeerOfConversation(conversationId);
    if (peer == null || !context.mounted) return;
    context.push('/chat/room/$peer');
  }
}
