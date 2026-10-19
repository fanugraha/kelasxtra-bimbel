import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/person_photo.dart';
import 'chat_providers.dart';
import 'chat_repository.dart';

/// Daftar percakapan bergaya aplikasi pesan: baris tanpa kartu, avatar kotak
/// membulat, cuplikan dua baris, waktu di kanan atas, dan centang hijau.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _search = TextEditingController();
  var _query = '';
  var _showSearch = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Conversation conv) async {
    await context.push(
      '/chat/room/${conv.peerId}',
      extra: {'name': conv.peerName, 'avatar': conv.peerAvatar},
    );
    if (mounted) ref.invalidate(conversationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final metaName = supabase.auth.currentUser?.userMetadata?['full_name'];
    final myName = metaName is String && metaName.trim().isNotEmpty
        ? metaName
        : 'Kamu';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              name: myName,
              showSearch: _showSearch,
              onSearch: () => setState(() => _showSearch = !_showSearch),
              onBell: () => context.push('/notifikasi'),
            ),
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _SearchField(
                  controller: _search,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: AsyncView<List<Conversation>>(
                value: conversations,
                errorTitle: 'Gagal memuat chat',
                onRetry: () => ref.invalidate(conversationsProvider),
                builder: (list) {
                  final filtered = _query.isEmpty
                      ? list
                      : list
                            .where(
                              (c) => c.peerName.toLowerCase().contains(_query),
                            )
                            .toList();

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(conversationsProvider);
                      await ref.read(conversationsProvider.future);
                    },
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 34),
                            children: [
                              EmptyState(
                                icon: list.isEmpty
                                    ? Icons.forum_outlined
                                    : Icons.search_off_rounded,
                                title: list.isEmpty
                                    ? 'Belum ada percakapan'
                                    : 'Tidak ditemukan',
                                message: list.isEmpty
                                    ? 'Chat terbuka setelah kamu memesan sesi. Riwayat obrolan dengan tutor akan muncul di sini.'
                                    : 'Coba kata kunci lain.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              thickness: 1,
                              indent: 20,
                              endIndent: 20,
                            ),
                            itemBuilder: (_, i) => _ConversationRow(
                              conv: filtered[i],
                              onTap: () => _open(filtered[i]),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.showSearch,
    required this.onSearch,
    required this.onBell,
  });

  final String name;
  final bool showSearch;
  final VoidCallback onSearch;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          PersonPhoto(name: name, size: 44, radius: 999),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pesan',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mari temukan pesan terbaru',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSearch,
            tooltip: 'Cari',
            style: IconButton.styleFrom(
              backgroundColor: showSearch
                  ? scheme.primary.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onBell,
            tooltip: 'Notifikasi',
            style: IconButton.styleFrom(
              backgroundColor: context.palette.brandSoft,
              foregroundColor: scheme.primary,
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari nama tutor',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conv, required this.onTap});

  final Conversation conv;
  final VoidCallback onTap;

  String get _preview {
    final body = conv.lastBody?.trim();
    if (body == null || body.isEmpty) return 'Belum ada pesan';
    return body.replaceAll('\n', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final unread = conv.unread > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonPhoto(
              name: conv.peerName,
              photoUrl: conv.peerAvatar,
              size: 54,
              radius: 14,
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
                          conv.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        AppFormat.chatStamp(conv.lastMessageAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: unread
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            height: 1.35,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: unread
                            ? _UnreadBadge(count: conv.unread)
                            : Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: palette.success,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
