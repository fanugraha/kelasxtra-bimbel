import '../../core/format.dart';
import '../katalog/katalog_repository.dart';
import '../paket/paket_repository.dart';

/// Tanggal yang mungkin untuk ganti hari: 14 hari ke depan, hanya hari yang
/// punya ketersediaan tutor pada mode sesi tersebut.
List<DateTime> rescheduleDates({
  required List<TutorAvailabilityItem> availability,
  required String mode,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final first = DateTime(
    clock.year,
    clock.month,
    clock.day,
  ).add(const Duration(days: 1));
  final days = {
    for (final a in availability)
      if (a.mode == mode) a.dayOfWeek,
  };
  return [
    for (var i = 0; i < 14; i++)
      if (days.contains(first.add(Duration(days: i)).weekday % 7))
        first.add(Duration(days: i)),
  ];
}

/// Jam mulai yang muat durasi sesi di jendela ketersediaan dan tidak bentrok
/// dengan sesi lain. Jam sesi lama dikecualikan karena slot itu akan dilepas.
/// Langkah 60 menit, sama dengan pemilih jadwal saat membeli paket.
List<int> rescheduleMinutes({
  required List<TutorAvailabilityItem> availability,
  required DateTime date,
  required String mode,
  required int durationMinutes,
  required List<BusySlot> busy,
  DateTime? oldStart,
}) {
  final starts = <int>{};
  final oldEnd = oldStart?.add(Duration(minutes: durationMinutes));
  for (final a in availability) {
    if (a.mode != mode || a.dayOfWeek != date.weekday % 7) continue;
    final from = AppFormat.minutesOfTime(a.startTime);
    final to = AppFormat.minutesOfTime(a.endTime);
    for (var m = from; m + durationMinutes <= to; m += 60) {
      final at = DateTime(date.year, date.month, date.day, 0, m);
      if (oldStart != null && at.isAtSameMomentAs(oldStart)) continue;
      final end = at.add(Duration(minutes: durationMinutes));
      final clash = busy.any((s) {
        if (oldStart != null &&
            oldEnd != null &&
            s.start.isAtSameMomentAs(oldStart) &&
            s.end.isAtSameMomentAs(oldEnd)) {
          return false;
        }
        return at.isBefore(s.end) && end.isAfter(s.start);
      });
      if (!clash) starts.add(m);
    }
  }
  return starts.toList()..sort();
}
