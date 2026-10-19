import '../../core/supabase_client.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.conversationId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? conversationId;

  /// Notifikasi pesan chat bisa dibuka langsung ke ruang obrolan.
  bool get isChat => type == 'chat.message' && conversationId != null;

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    final data = (m['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppNotification(
      id: m['id'] as String,
      type: (m['type'] ?? '-') as String,
      title: (m['title'] ?? '') as String,
      body: (m['body'] ?? '') as String,
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      read: m['read_at'] != null,
      conversationId: data['conversation_id'] as String?,
    );
  }
}

class NotificationRepository {
  Future<List<AppNotification>> fetchMine() async {
    final rows = await supabase
        .from('notifications')
        .select('id, type, title, body, data, created_at, read_at')
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows) AppNotification.fromMap(r)];
  }

  Future<void> markRead(String id) async {
    await supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
