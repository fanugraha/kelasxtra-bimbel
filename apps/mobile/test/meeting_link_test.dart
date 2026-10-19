import 'package:bimbel_mobile/core/meeting_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 20, 16, 0);
  const zoom = 'https://us02web.zoom.us/j/8123456789';

  MeetingStatus at(
    DateTime now, {
    String mode = 'online',
    String status = 'confirmed',
    String? url = zoom,
    int minutes = 90,
  }) => meetingStatus(
    mode: mode,
    status: status,
    scheduledAt: start,
    durationMinutes: minutes,
    url: url,
    now: now,
  );

  test('sesi offline tidak punya tombol gabung', () {
    expect(at(start, mode: 'offline').phase, MeetingPhase.tidakBerlaku);
  });

  test('sebelum lunas/batal tidak relevan walau tautan ada', () {
    expect(
      at(start, status: 'pending_payment').phase,
      MeetingPhase.tidakBerlaku,
    );
    expect(at(start, status: 'cancelled').phase, MeetingPhase.tidakBerlaku);
  });

  test('online tanpa tautan menunggu tentor', () {
    expect(at(start, url: null).phase, MeetingPhase.belumAdaLink);
    expect(at(start, url: '   ').phase, MeetingPhase.belumAdaLink);
  });

  test('sehari sebelum sesi masih terkunci', () {
    final s = at(start.subtract(const Duration(hours: 5)));
    expect(s.phase, MeetingPhase.belumWaktunya);
    expect(s.opensAt, start.subtract(meetingOpenBefore));
    expect(s.canJoin, isFalse);
  });

  test('aktif mulai 15 menit sebelum jadwal', () {
    expect(
      at(start.subtract(const Duration(minutes: 15))).phase,
      MeetingPhase.bisaGabung,
    );
    expect(
      at(start.subtract(const Duration(minutes: 16))).phase,
      MeetingPhase.belumWaktunya,
    );
    expect(at(start).phase, MeetingPhase.bisaGabung);
    expect(
      at(start.add(const Duration(minutes: 30))).phase,
      MeetingPhase.bisaGabung,
    );
  });

  test('berhenti 15 menit setelah sesi berakhir', () {
    expect(
      at(start.add(const Duration(minutes: 105))).phase,
      MeetingPhase.bisaGabung,
    );
    expect(
      at(start.add(const Duration(minutes: 106))).phase,
      MeetingPhase.sudahLewat,
    );
  });
}
