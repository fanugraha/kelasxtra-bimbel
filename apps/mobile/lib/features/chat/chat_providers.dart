import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../auth/auth_providers.dart';
import 'chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(),
);

/// Detak perubahan pesan dari server (realtime). Setiap pesan baru/berubah
/// memicu penyegaran daftar percakapan sehingga lencana belum dibaca ikut hidup.
/// Nilainya sengaja berubah (penghitung) agar Riverpod menganggapnya baru.
final chatTickProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(authStateProvider).value?.session?.user.id;
  if (userId == null) return const Stream<int>.empty();

  final controller = StreamController<int>();
  var tick = 0;
  final channel = supabase.channel('kx-chat-$userId');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversation_messages',
        callback: (_) => controller.add(++tick),
      )
      .subscribe();

  ref.onDispose(() {
    controller.close();
    supabase.removeChannel(channel);
  });
  return controller.stream;
});

/// Daftar percakapan milik pengguna yang login (urut pesan terbaru).
final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  ref.watch(authStateProvider);
  ref.watch(chatTickProvider);
  return ref.read(chatRepositoryProvider).fetchConversations();
});

/// Jumlah pesan yang belum dibaca — dipakai lencana di tab Chat.
final chatUnreadProvider = Provider<int>((ref) {
  final list = ref.watch(conversationsProvider).value;
  if (list == null) return 0;
  return list.fold<int>(0, (sum, c) => sum + c.unread);
});

/// Percakapan dengan satu orang; dibuka (dibuat bila perlu) di server.
final conversationIdProvider = FutureProvider.family<String, String>((
  ref,
  peerId,
) {
  ref.watch(authStateProvider);
  return ref.read(chatRepositoryProvider).ensureConversation(peerId);
});

/// Pesan satu percakapan (realtime, urut waktu).
final conversationMessagesProvider =
    StreamProvider.family<List<ConversationMessage>, String>((ref, id) {
      ref.watch(authStateProvider);
      return ref.read(chatRepositoryProvider).watchMessages(id);
    });

/// Nama + foto lawan bicara, diambil dari view (bukan dari tabel profil).
final conversationPeerProvider = FutureProvider.family<Conversation?, String>((
  ref,
  peerId,
) {
  ref.watch(authStateProvider);
  ref.watch(chatTickProvider);
  return ref.read(chatRepositoryProvider).fetchWithPeer(peerId);
});

/// Percakapan yang sedang dibuka pengguna — dipakai agar pesan yang sedang
/// dibaca tidak memunculkan notifikasi pop-up.
class OpenChatPeer extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? peerId) => state = peerId;
}

final openChatPeerProvider = NotifierProvider<OpenChatPeer, String?>(
  OpenChatPeer.new,
);
