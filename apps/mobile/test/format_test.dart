import 'package:bimbel_mobile/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rupiah', () {
    expect(AppFormat.rupiah(0), 'Rp0');
    expect(AppFormat.rupiah(500), 'Rp500');
    expect(AppFormat.rupiah(75000), 'Rp75.000');
    expect(AppFormat.rupiah(165000), 'Rp165.000');
    expect(AppFormat.rupiah(1000000), 'Rp1.000.000');
  });

  test('hhmm / minutesOfTime / timeRange', () {
    expect(AppFormat.hhmm(960), '16:00');
    expect(AppFormat.hhmm(90), '01:30');
    expect(AppFormat.minutesOfTime('16:30:00'), 990);
    expect(AppFormat.minutesOfTime('09:00'), 540);
    expect(AppFormat.timeRange('16:00:00', '18:00:00'), '16:00–18:00');
    expect(AppFormat.shortTime('07:05:00'), '07:05');
    expect(AppFormat.clock(0), '00:00');
    expect(AppFormat.clock(125), '02:05');
    expect(AppFormat.clock(1200), '20:00');
  });

  test('nama hari (0 = Minggu)', () {
    expect(AppFormat.longDayName(0), 'Minggu');
    expect(AppFormat.longDayName(6), 'Sabtu');
  });

  test('tanggal ringkas', () {
    expect(AppFormat.dateShort(DateTime(2026, 10, 19)), 'Sen, 19 Okt');
    expect(
      AppFormat.dateTimeShort(DateTime(2026, 10, 17, 9, 0)),
      'Sab, 17 Okt · 09:00',
    );
  });
}
