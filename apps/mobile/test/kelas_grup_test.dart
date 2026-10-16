import 'package:bimbel_mobile/features/kelas_grup/kelas_grup_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GroupClassItem.fromMap + turunan', () {
    final item = GroupClassItem.fromMap({
      'id': 'c1',
      'jenjang': 'SMA',
      'mode': 'offline',
      'duration_minutes': 90,
      'total_sesi': 8,
      'discount_percent': 5,
      'price_per_session': 75000,
      'price_total': 570000,
      'min_seats': 3,
      'max_seats': 5,
      'seats_taken': 2,
      'status': 'open',
      'min_confirm_deadline': '2026-10-19T13:00:00Z',
      'tutor_name': 'Budi',
      'subject_name': 'Matematika',
      'first_session': '2026-10-20T09:00:00Z',
      'last_session': '2026-11-12T09:00:00Z',
    });

    expect(item.tutorName, 'Budi');
    expect(item.subjectName, 'Matematika');
    expect(item.sisaKursi, 3);
    expect(item.penuh, false);
    expect(item.dibuka, true);
    expect(item.firstSession, isNotNull);
  });

  test('GroupSeatItem status label', () {
    final seat = GroupSeatItem.fromMap({
      'id': 's1',
      'group_class_id': 'c1',
      'price_paid': 570000,
      'status': 'refund_pending',
      'refund_amount': 570000,
    });
    expect(seat.statusLabel, 'Menunggu refund');
    expect(seat.refundAmount, 570000);
  });

  test('kelas penuh terdeteksi', () {
    final item = GroupClassItem.fromMap({
      'id': 'c2',
      'jenjang': 'SD',
      'mode': 'online',
      'duration_minutes': 90,
      'total_sesi': 4,
      'discount_percent': 0,
      'price_per_session': 45000,
      'price_total': 180000,
      'min_seats': 3,
      'max_seats': 5,
      'seats_taken': 5,
      'status': 'open',
      'min_confirm_deadline': '2026-10-19T13:00:00Z',
    });
    expect(item.penuh, true);
    expect(item.sisaKursi, 0);
  });
}
