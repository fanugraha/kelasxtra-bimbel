import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// Satu percakapan 1:1 dengan tutor/siswa (dibaca dari view `my_conversations`).
///
/// View hanya membuka nama + foto lawan bicara. Nomor HP/email tidak pernah
/// ikut, jadi walaupun data bocor dari sisi klien, tidak ada kontak pribadi.
class Conversation {
  const Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.lastMessageAt,
    required this.unread,
    this.peerAvatar,
    this.lastBody,
  });

  final String id;
  final String peerId;
  final String peerName;
  final String? peerAvatar;
  final String? lastBody;
  final DateTime lastMessageAt;
  final int unread;

  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
    id: m['id'] as String,
    peerId: m['peer_id'] as String,
    peerName: (m['peer_name'] ?? 'Pengguna') as String,
    peerAvatar: m['peer_avatar'] as String?,
    lastBody: m['last_body'] as String?,
    lastMessageAt: DateTime.parse(m['last_message_at'] as String).toLocal(),
    unread: (m['unread'] as num?)?.toInt() ?? 0,
  );
}

/// Satu pesan di dalam percakapan.
class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory ConversationMessage.fromMap(Map<String, dynamic> m) =>
      ConversationMessage(
        id: m['id'] as String,
        senderId: m['sender_id'] as String,
        body: (m['body'] ?? '') as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        readAt: m['read_at'] == null
            ? null
            : DateTime.parse(m['read_at'] as String).toLocal(),
      );

  bool isMine(String? userId) => senderId == userId;
  bool get read => readAt != null;
}

/// Akses percakapan per tutor: baca daftar, buka ruang, kirim pesan.
///
/// Semua penulisan lewat RPC agar penyaring isi (nomor HP/tautan/ajakan bayar
/// di luar aplikasi) selalu berjalan di server, tidak bisa dilewati klien.
class ChatRepository {
  static const _conversationColumns =
      'id, peer_id, peer_name, peer_avatar, last_body, last_message_at, unread';

  Future<List<Conversation>> fetchConversations() async {
    final rows = await supabase
        .from('my_conversations')
        .select(_conversationColumns)
        .order('last_message_at', ascending: false);
    return [for (final r in rows) Conversation.fromMap(r)];
  }

  /// Ambil satu percakapan dengan lawan bicara tertentu (null bila belum ada).
  Future<Conversation?> fetchWithPeer(String peerId) async {
    final row = await supabase
        .from('my_conversations')
        .select(_conversationColumns)
        .eq('peer_id', peerId)
        .maybeSingle();
    return row == null ? null : Conversation.fromMap(row);
  }

  /// Aliran pesan satu percakapan (realtime, urut waktu: lama ke baru).
  Stream<List<ConversationMessage>> watchMessages(String conversationId) {
    return supabase
        .from('conversation_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => [for (final r in rows) ConversationMessage.fromMap(r)]);
  }

  /// Buka percakapan; server menolak bila belum ada sesi dengan orang ini.
  Future<String> ensureConversation(String peerId) async {
    try {
      final id = await supabase.rpc(
        'ensure_conversation',
        params: {'p_other': peerId},
      );
      return id as String;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Kirim pesan. Melempar bila isi ditolak penyaring keamanan.
  Future<void> sendMessage({
    required String peerId,
    required String body,
  }) async {
    try {
      final res = await supabase.rpc(
        'send_conversation_message',
        params: {'p_other': peerId, 'p_body': body},
      );
      final map = (res as Map).cast<String, dynamic>();
      if (map['ok'] != true) {
        throw Exception((map['error'] ?? 'Pesan tidak terkirim.') as String);
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> markRead(String conversationId) async {
    await supabase.rpc(
      'mark_conversation_read',
      params: {'p_conversation': conversationId},
    );
  }

  /// Lawan bicara dari sebuah percakapan (dipakai saat membuka notifikasi).
  Future<String?> fetchPeerOfConversation(String conversationId) async {
    final row = await supabase
        .from('conversations')
        .select('student_id, tutor_id')
        .eq('id', conversationId)
        .maybeSingle();
    if (row == null) return null;
    final uid = supabase.auth.currentUser?.id;
    final student = row['student_id'] as String;
    final tutor = row['tutor_id'] as String;
    return student == uid ? tutor : student;
  }
}
