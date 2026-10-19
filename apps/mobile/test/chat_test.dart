import 'package:bimbel_mobile/core/format.dart';
import 'package:bimbel_mobile/features/chat/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Conversation.fromMap membaca view my_conversations', () {
    final conv = Conversation.fromMap({
      'id': 'c1',
      'peer_id': 'p1',
      'peer_name': 'Andi Pratama',
      'peer_avatar': null,
      'last_body': 'Besok kita bahas trigonometri ya',
      'last_message_at': '2026-10-18T02:00:00.000Z',
      'unread': 2,
    });
    expect(conv.peerName, 'Andi Pratama');
    expect(conv.unread, 2);
    expect(conv.lastMessageAt.isUtc, isFalse);
  });

  test('ConversationMessage.isMine + read', () {
    final msg = ConversationMessage.fromMap({
      'id': 'm1',
      'sender_id': 'p1',
      'body': 'Halo',
      'created_at': '2026-10-18T02:00:00.000Z',
      'read_at': null,
    });
    expect(msg.isMine('p1'), isTrue);
    expect(msg.isMine('p2'), isFalse);
    expect(msg.read, isFalse);
  });

  test('chatStamp: jam hari ini, kemarin, beberapa hari, lalu tanggal', () {
    final now = DateTime.now();
    expect(AppFormat.chatStamp(DateTime(now.year, now.month, now.day, 9, 30)),
        '09.30');
    expect(
      AppFormat.chatStamp(now.subtract(const Duration(days: 1))),
      'Kemarin',
    );
    expect(
      AppFormat.chatStamp(now.subtract(const Duration(days: 3))).length,
      lessThanOrEqualTo(4),
    );
    final old = AppFormat.chatStamp(now.subtract(const Duration(days: 30)));
    expect(old.contains(' '), isTrue);
  });
}
