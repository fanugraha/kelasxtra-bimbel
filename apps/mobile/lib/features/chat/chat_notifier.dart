import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../notifikasi/notifikasi_providers.dart';
import 'chat_providers.dart';

/// Penjaga notifikasi pesan masuk saat aplikasi sedang dibuka.
///
/// Saat ada pesan baru dari server (realtime), muncul pita singkat di bawah:
/// "Pesan baru dari (nama)" dengan tombol "Buka". Pesan yang sedang dibaca
/// di ruang chat tidak memunculkan pita.
class ChatInboxWatcher extends ConsumerStatefulWidget {
  const ChatInboxWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatInboxWatcher> createState() => _ChatInboxWatcherState();
}

class _ChatInboxWatcherState extends ConsumerState<ChatInboxWatcher> {
  Timer? _debounce;
  String? _lastNotified;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _check);
  }

  Future<void> _check() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || !mounted) return;

    try {
      final rows = await supabase
          .from('conversation_messages')
          .select('id, body, conversation_id, created_at, sender_id')
          .neq('sender_id', uid)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty || !mounted) return;

      final row = rows.first;
      final id = row['id'] as String;
      if (id == _lastNotified) return;
      _lastNotified = id;

      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      if (DateTime.now().difference(createdAt) > const Duration(minutes: 2)) {
        return;
      }

      final peer = await ref
          .read(chatRepositoryProvider)
          .fetchPeerOfConversation(row['conversation_id'] as String);
      if (peer == null || peer == ref.read(openChatPeerProvider) || !mounted) {
        return;
      }

      var name = 'Pengguna';
      for (final c in ref.read(conversationsProvider).value ?? const []) {
        if (c.peerId == peer) {
          name = c.peerName;
          break;
        }
      }

      final body = (row['body'] as String).replaceAll('\n', ' ');
      // Daftar notifikasi & titik merah di beranda ikut disegarkan.
      ref.invalidate(myNotificationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            'Pesan baru dari $name: $body',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: 'Buka',
            onPressed: () =>
                context.push('/chat/room/$peer', extra: {'name': name}),
          ),
        ),
      );
    } catch (_) {
      // Notifikasi pop-up bersifat tambahan: kegagalan jaringan cukup diabaikan,
      // lencana belum dibaca tetap diperbarui oleh daftar percakapan.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatTickProvider, (_, _) => _schedule());
    return widget.child;
  }
}
