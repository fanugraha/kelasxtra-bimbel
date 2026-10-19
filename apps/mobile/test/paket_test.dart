import 'package:bimbel_mobile/features/katalog/katalog_repository.dart';
import 'package:bimbel_mobile/features/paket/beli_paket/beli_paket_controller.dart';
import 'package:bimbel_mobile/features/paket/paket_providers.dart';
import 'package:bimbel_mobile/features/paket/paket_repository.dart';
import 'package:flutter_test/flutter_test.dart';

BeliPaketController _controller() => BeliPaketController(
      tutorId: 't',
      repository: PaketRepository(),
      invalidateBusy: () {},
    );

void main() {
  test('paketSizeLabel: masa berlaku mengikuti jumlah pertemuan', () {
    expect(paketSizeLabel(4), '4 pertemuan · 1 bulan');
    expect(paketSizeLabel(8), '8 pertemuan · 2 bulan');
    expect(paketSizeLabel(12), '12 pertemuan · 3 bulan');
  });

  test('paketPerSesi: harga paket dibagi jumlah pertemuan', () {
    expect(paketPerSesi(340000, 4), 85000);
    expect(paketPerSesi(646000, 8), 80750);
    expect(paketPerSesi(null, 4), isNull);
  });

  test('paketSizeOptions hanya 4, 8, 12', () {
    expect(paketSizeOptions, [4, 8, 12]);
  });

  test('meetingDates: pertemuan tiap 7 hari sejumlah paket', () {
    final c = _controller()
      ..selectSize(4)
      ..selectDate(DateTime(2026, 10, 19));
    expect(c.meetingDates(), [
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 26),
      DateTime(2026, 11, 2),
      DateTime(2026, 11, 9),
    ]);
  });

  test('nextDates: Senin terdekat sejak hari Minggu', () {
    final c = _controller();
    final dates = c.nextDates(1, now: DateTime(2026, 10, 18));
    expect(dates.first, DateTime(2026, 10, 19));
    expect(dates.length, 4);
  });

  test('meetingsFree: bentrok di salah satu pertemuan mingguan terdeteksi', () {
    final c = _controller()
      ..selectSize(4)
      ..selectDate(DateTime(2026, 10, 19));
    final busy = [
      BusySlot(
        start: DateTime(2026, 10, 26, 16),
        end: DateTime(2026, 10, 26, 17),
      ),
    ];
    // 16:00 bertabrakan dengan pertemuan ke-2 (26 Okt).
    expect(c.meetingsFree(DateTime(2026, 10, 19), 960, busy), isFalse);
    // 15:00 tidak bertabrakan.
    expect(c.meetingsFree(DateTime(2026, 10, 19), 900, busy), isTrue);
  });

  test('startTimes: hanya jam yang muat durasi & bebas bentrok', () {
    final c = _controller()..selectDuration(60);
    const slot = TutorAvailabilityItem(
      dayOfWeek: 1,
      startTime: '16:00:00',
      endTime: '18:00:00',
      mode: 'online',
    );
    final times = c.startTimes(
      date: DateTime(2026, 10, 19),
      slot: slot,
      busy: const [],
      now: DateTime(2026, 10, 18),
    );
    expect(times, [960, 1020]); // 16:00 & 17:00
  });
}
