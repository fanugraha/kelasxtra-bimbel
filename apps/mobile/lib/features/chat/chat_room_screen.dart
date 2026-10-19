import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';

import '../../core/theme/app_theme.dart';
import '../../core/supabase_client.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/person_photo.dart';
import 'chat_providers.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/safety_note.dart';

/// Ruang obrolan 1:1 dengan satu tutor/siswa.
///
/// Pesan dikirim lewat server agar penyaring isi selalu berjalan: nomor HP,
/// email, tautan, dan ajakan pembayaran di luar aplikasi akan ditolak dan
/// pengguna menerima penjelasan.
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.peerId,
    this.peerName,
    this.peerAvatar,
  });

  final String peerId;
  final String? peerName;
  final String? peerAvatar;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _sending = false;
  var _marking = false;

  @override
  void initState() {
    super.initState();
    // Tandai ruang ini sedang dibuka agar pesan masuk tidak jadi pop-up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(openChatPeerProvider.notifier).set(widget.peerId);
    });
  }

  @override
  void didUpdateWidget(ChatRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peerId != widget.peerId) {
      ref.read(openChatPeerProvider.notifier).set(widget.peerId);
    }
  }

  @override
  void dispose() {
    ref.read(openChatPeerProvider.notifier).set(null);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _markRead(String conversationId) async {
    if (_marking) return;
    _marking = true;
    try {
      await ref.read(chatRepositoryProvider).markRead(conversationId);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      // Daftar belum dibaca akan tersinkron lagi saat layar dibuka ulang.
    } finally {
      _marking = false;
    }
  }

  Future<void> _send(String conversationId) async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(peerId: widget.peerId, body: body);
      _input.clear();
      _scrollToEnd();
      ref.invalidate(conversationsProvider);
    } catch (e) {
      _toast(cleanError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conversationId = ref.watch(conversationIdProvider(widget.peerId));
    final peer = ref.watch(conversationPeerProvider(widget.peerId)).value;
    final name = peer?.peerName ?? widget.peerName ?? 'Percakapan';
    final avatar = peer?.peerAvatar ?? widget.peerAvatar;

    final id = conversationId.value;
    if (id != null) {
      ref.listen(conversationMessagesProvider(id), (_, next) {
        final list = next.value;
        if (list == null || list.isEmpty) return;
        final uid = supabase.auth.currentUser?.id;
        if (list.any((m) => !m.isMine(uid) && !m.read)) {
          _markRead(id);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            PersonPhoto(name: name, photoUrl: avatar, size: 44, radius: 12),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Percakapan privat',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: conversationId.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Chat belum bisa dibuka',
          message: cleanError(error),
          action: FilledButton.icon(
            onPressed: () =>
                ref.invalidate(conversationIdProvider(widget.peerId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ),
        data: (conversationId) => Column(
          children: [
            Expanded(child: _messages(conversationId)),
            _composer(conversationId),
          ],
        ),
      ),
    );
  }

  Widget _messages(String conversationId) {
    final messages = ref.watch(conversationMessagesProvider(conversationId));
    final uid = supabase.auth.currentUser?.id;

    return messages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Gagal memuat pesan',
        message: '$error',
        action: FilledButton.icon(
          onPressed: () =>
              ref.invalidate(conversationMessagesProvider(conversationId)),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba lagi'),
        ),
      ),
      data: (list) {
        _scrollToEnd();
        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          children: [
            const ChatSafetyNote(),
            const SizedBox(height: 14),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Mulai percakapan',
                  message:
                      'Sapa dulu, lalu tanyakan jadwal atau materi yang ingin dibahas.',
                ),
              )
            else
              for (var i = 0; i < list.length; i++)
                ChatBubble(
                  message: list[i],
                  mine: list[i].isMine(uid),
                  lastMine:
                      list[i].isMine(uid) &&
                      !list.skip(i + 1).any((m) => m.isMine(uid)),
                ),
          ],
        );
      },
    );
  }

  Widget _composer(String conversationId) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan',
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: FilledButton(
                onPressed: _sending ? null : () => _send(conversationId),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
