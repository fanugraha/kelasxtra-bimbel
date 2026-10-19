import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import 'chat_providers.dart';
import 'chat_repository.dart';

/// Daftar percakapan bergaya aplikasi pesan: satu baris per tutor/siswa,
/// pesan terbaru di atas, lencana jumlah pesan yang belum dibaca.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _search = TextEditingController();
  var _query = '';

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

    return Scaffold(
      body: SafeArea(
        child: AsyncView<List<Conversation>>(
          value: conversations,
          errorTitle: 'Gagal memuat chat',
          onRetry: () => ref.invalidate(conversationsProvider),
          builder: (list) {
            final filtered = _query.isEmpty
                ? list
                : list
                    .where((c) => c.peerName.toLowerCase().contains(_query))
                    .toList();

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(conversationsProvider);
                await ref.read(conversationsProvider.future);
              },
              child: ListView(
                padding: screenPadding,
                children: [
                  const ScreenHead(
                    eyebrow: 'Pesan',
                    title: 'Chat',
                    subtitle:
                        'Tanya jadwal, materi, atau persiapan sesi ke tutor.',
                  ),
                  const SizedBox(height: 16),
                  _SearchField(
                    controller: _search,
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 14),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 34),
                      child: EmptyState(
                        icon: Icons.forum_outlined,
                        title: 'Belum ada percakapan',
                        message:
                            'Chat terbuka setelah kamu memesan sesi. Riwayat obrolan dengan tutor akan muncul di sini.',
                      ),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 34),
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Tidak ditemukan',
                        message: 'Coba kata kunci lain.',
                      ),
                    )
                  else
                    for (final conv in filtered) ...[
                      _ConversationCard(
                        conv: conv,
                        onTap: () => _open(conv),
                      ),
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
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari nama tutor',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conv, required this.onTap});

  final Conversation conv;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = conv.unread > 0;
    final initial = conv.peerName.isEmpty ? '?' : conv.peerName[0].toUpperCase();
    final hasPhoto = conv.peerAvatar != null && conv.peerAvatar!.isNotEmpty;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primary.withValues(alpha: 0.11),
            backgroundImage: hasPhoto ? NetworkImage(conv.peerAvatar!) : null,
            child: hasPhoto
                ? null
                : Text(
                    initial,
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conv.peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13.5,
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conv.lastBody?.trim().isNotEmpty == true
                            ? conv.lastBody!.replaceAll('\n', ' ')
                            : 'Belum ada pesan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          color: unread
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppFormat.chatStamp(conv.lastMessageAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                        color: unread ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (unread) ...[
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                conv.unread > 99 ? '99+' : '${conv.unread}',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
