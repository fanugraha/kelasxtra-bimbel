import 'package:bimbel_mobile/features/booking/reschedule_slots.dart';
import 'package:bimbel_mobile/features/katalog/katalog_repository.dart';
import 'package:bimbel_mobile/features/paket/paket_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _tuesday = TutorAvailabilityItem(
  dayOfWeek: 2,
  startTime: '15:00:00',
  endTime: '18:00:00',
  mode: 'online',
);

void main() {
  test('tanggal hanya hari tersedia pada mode sesi', () {
    final dates = rescheduleDates(
      availability: const [_tuesday],
      mode: 'online',
      now: DateTime(2026, 10, 19),
    );
    expect(dates.first, DateTime(2026, 10, 20));
    expect(dates.every((d) => d.weekday == DateTime.tuesday), isTrue);
    expect(dates.length, 2);
  });

  test('jam muat durasi, sibuk dilewati, slot lama dikecualikan', () {
    final date = DateTime(2026, 10, 20);
    final minutes = rescheduleMinutes(
      availability: const [_tuesday],
      date: date,
      mode: 'online',
      durationMinutes: 90,
      busy: [
        BusySlot(
          start: DateTime(2026, 10, 20, 17),
          end: DateTime(2026, 10, 20, 18),
        ),
      ],
    );
    expect(minutes, [15 * 60]);

    final withOld = rescheduleMinutes(
      availability: const [_tuesday],
      date: date,
      mode: 'online',
      durationMinutes: 90,
      busy: [
        BusySlot(
          start: DateTime(2026, 10, 20, 15),
          end: DateTime(2026, 10, 20, 16, 30),
        ),
      ],
      oldStart: DateTime(2026, 10, 20, 15),
    );
    expect(withOld, [16 * 60]);
  });

  test('mode lain tidak menghasilkan slot', () {
    expect(
      rescheduleMinutes(
        availability: const [_tuesday],
        date: DateTime(2026, 10, 20),
        mode: 'offline',
        durationMinutes: 60,
        busy: const [],
      ),
      isEmpty,
    );
  });
}
