import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../chat/chat_providers.dart';
import 'notifikasi_providers.dart';
import 'notifikasi_repository.dart';

/// Notifikasi dikelompokkan per jenis info supaya siswa/tutor langsung tahu
/// ini tentang apa: pesan, jadwal, keuangan, ulasan, atau peringatan.
enum _Group { pesan, jadwal, keuangan, ulasan, peringatan, lain }

_Group _groupOf(AppNotification n) => switch (n.type) {
  'chat.message' => _Group.pesan,
  'booking' || 'session' || 'reschedule' => _Group.jadwal,
  'credit' || 'subscription' || 'payroll' => _Group.keuangan,
  'review' || 'complaint' => _Group.ulasan,
  'moderation.warning' => _Group.peringatan,
  _ => _Group.lain,
};

extension on _Group {
  String get label => switch (this) {
    _Group.pesan => 'Pesan',
    _Group.jadwal => 'Jadwal & sesi',
    _Group.keuangan => 'Keuangan',
    _Group.ulasan => 'Ulasan & komplain',
    _Group.peringatan => 'Peringatan',
    _Group.lain => 'Lainnya',
  };

  IconData get icon => switch (this) {
    _Group.pesan => Icons.forum_rounded,
    _Group.jadwal => Icons.event_available_rounded,
    _Group.keuangan => Icons.account_balance_wallet_rounded,
    _Group.ulasan => Icons.star_rounded,
    _Group.peringatan => Icons.shield_outlined,
    _Group.lain => Icons.notifications_rounded,
  };

  Color color(AppPalette p) => switch (this) {
    _Group.pesan => p.brand,
    _Group.jadwal => p.info,
    _Group.keuangan => p.success,
    _Group.ulasan => p.reward,
    _Group.peringatan => p.warning,
    _Group.lain => p.challenge,
  };

  Color soft(AppPalette p) => switch (this) {
    _Group.pesan => p.brandSoft,
    _Group.jadwal => p.infoSoft,
    _Group.keuangan => p.successSoft,
    _Group.ulasan => p.rewardSoft,
    _Group.peringatan => p.warningSoft,
    _Group.lain => p.challengeSoft,
  };
}

class NotifikasiScreen extends ConsumerStatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  ConsumerState<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends ConsumerState<NotifikasiScreen> {
  @override
  void initState() {
    super.initState();
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
            final unread = list.where((n) => !n.read).length;
            final groups = <_Group, List<AppNotification>>{};
            for (final n in list) {
              groups.putIfAbsent(_groupOf(n), () => []).add(n);
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myNotificationsProvider);
                await ref.read(myNotificationsProvider.future);
              },
              child: ListView(
                padding: screenPadding,
                children: [
                  ScreenHead(
                    showBack: true,
                    title: 'Notifikasi',
                    subtitle: unread > 0
                        ? '$unread belum dibaca · info sesi, pembayaran, dan aktivitas belajar.'
                        : 'Info sesi, pembayaran, dan aktivitas belajar.',
                  ),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Belum ada notifikasi',
                        message:
                            'Info sesi, pembayaran, dan aktivitas belajarmu akan muncul di sini.',
                      ),
                    )
                  else ...[
                    const SizedBox(height: 16),
                    _Summary(
                      total: list.length,
                      unread: unread,
                      onReadAll: () async {
                        await ref
                            .read(notificationRepositoryProvider)
                            .markAllRead();
                        ref.invalidate(myNotificationsProvider);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    for (final g in _Group.values)
                      if (groups[g] case final section?) ...[
                        _GroupHead(
                          group: g,
                          total: section.length,
                          unread: section.where((n) => !n.read).length,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _GroupCard(items: section),
                        const SizedBox(height: AppSpacing.lg + 4),
                      ],
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

class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.unread,
    required this.onReadAll,
  });

  final int total;
  final int unread;
  final Future<void> Function() onReadAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            unread > 0
                ? Icons.mark_email_unread_rounded
                : Icons.mark_email_read_rounded,
            size: 20,
            color: palette.brand,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              unread > 0
                  ? '$unread belum dibaca dari $total notifikasi'
                  : 'Semua notifikasi sudah dibaca',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (unread > 0)
            TextLink(label: 'Tandai semua', onTap: () => onReadAll()),
        ],
      ),
    );
  }
}

class _GroupHead extends StatelessWidget {
  const _GroupHead({
    required this.group,
    required this.total,
    required this.unread,
  });

  final _Group group;
  final int total;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final color = group.color(palette);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: group.soft(palette),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(group.icon, size: 16, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            group.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: group.soft(palette),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            unread > 0 ? '$unread baru' : '$total',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.items});

  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 14,
                  color: scheme.outline,
                ),
              _NotifRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotifRow extends ConsumerWidget {
  const _NotifRow({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final group = _groupOf(item);
    final color = group.color(context.palette);
    final soft = group.soft(context.palette);
    final canOpen =
        item.conversationId != null || item.bookingId != null || !item.read;

    return Material(
      color: item.read
          ? Colors.transparent
          : soft.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.55 : 0.45,
            ),
      child: InkWell(
        onTap: canOpen ? () => _open(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(group.icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: item.read
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (!item.read) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.45,
                        color: item.read
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 1),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppFormat.chatStamp(item.createdAt),
                          style: theme.textTheme.labelSmall,
                        ),
                        if (_hint(item) case final hint?) ...[
                          const Spacer(),
                          Text(
                            hint,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 15,
                            color: color,
                          ),
                        ],
                      ],
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

  String? _hint(AppNotification n) {
    if (n.isChat) return 'Balas pesan';
    if (n.bookingId != null) return 'Lihat sesi';
    if (!n.read) return 'Tandai dibaca';
    return null;
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final wasUnread = !item.read;
    if (wasUnread) {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
    }
    if (!context.mounted) return;

    final conversationId = item.conversationId;
    if (conversationId != null) {
      final peer = await ref
          .read(chatRepositoryProvider)
          .fetchPeerOfConversation(conversationId);
      if (peer != null && context.mounted) context.push('/chat/room/$peer');
    } else if (item.bookingId case final bookingId?) {
      context.push('/sesi/$bookingId');
    }

    // Segarkan setelah pindah layar agar baris tidak hilang saat diketuk.
    if (wasUnread) ref.invalidate(myNotificationsProvider);
  }
}
