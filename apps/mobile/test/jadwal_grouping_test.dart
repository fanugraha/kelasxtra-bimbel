import 'package:bimbel_mobile/features/booking/booking_repository.dart';
import 'package:bimbel_mobile/features/jadwal/jadwal_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

BookingItem _b(
  String id, {
  required String tutor,
  required DateTime at,
  String status = 'confirmed',
  String subject = 'Matematika',
  String student = 's-1',
  int duration = 90,
}) => BookingItem(
  id: id,
  tutorId: tutor,
  studentId: student,
  tutorName: 'Kak $tutor',
  studentName: 'Siswa $student',
  subjectName: subject,
  jenjang: 'SMA',
  durationMinutes: duration,
  mode: 'online',
  scheduledAt: at,
  status: status,
  price: 0,
);

void main() {
  final now = DateTime(2026, 10, 19, 8);
  DateTime d(int days, [int h = 16]) =>
      DateTime(now.year, now.month, now.day + days, h);

  test('tutor diurut dari sesi terdekat; yang tinggal riwayat di bawah', () {
    final people = groupJadwal([
      _b('1', tutor: 'budi', at: d(3)),
      _b('2', tutor: 'rani', at: d(1)),
      _b('3', tutor: 'sinta', at: d(-2), status: 'completed'),
      _b('4', tutor: 'dita', at: d(-1), status: 'completed'),
      _b('5', tutor: 'budi', at: d(2)),
    ], isSiswa: true);

    expect(people.map((p) => p.id), ['rani', 'budi', 'dita', 'sinta']);
    expect(people[1].next!.id, '5');
    expect(people[1].upcoming.map((b) => b.id), ['5', '1']);
  });

  test('belum lunas & kedaluwarsa disembunyikan', () {
    final people = groupJadwal([
      _b('1', tutor: 'budi', at: d(1), status: 'pending_payment'),
      _b('2', tutor: 'rani', at: d(1), status: 'expired'),
    ], isSiswa: true);
    expect(people, isEmpty);
  });

  test('riwayat terbaru dulu, jam belajar hanya dari sesi selesai', () {
    final p = groupJadwal([
      _b('1', tutor: 'budi', at: d(-5), status: 'completed', duration: 60),
      _b('2', tutor: 'budi', at: d(-1), status: 'completed', duration: 90),
      _b('3', tutor: 'budi', at: d(-3), status: 'cancelled'),
      _b('4', tutor: 'budi', at: d(2), subject: 'Fisika'),
    ], isSiswa: true).single;

    expect(p.history.map((b) => b.id), ['2', '3', '1']);
    expect(p.completedCount, 2);
    expect(p.completedHours, 2.5);
    expect(p.subjects, ['Matematika', 'Fisika']);
  });

  test('aplikasi tutor mengelompokkan per siswa', () {
    final people = groupJadwal([
      _b('1', tutor: 't', student: 'a', at: d(2)),
      _b('2', tutor: 't', student: 'b', at: d(1)),
    ], isSiswa: false);
    expect(people.map((p) => p.name), ['Siswa b', 'Siswa a']);
  });
}
