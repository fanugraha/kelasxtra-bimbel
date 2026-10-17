/// Pemformatan bersama (uang, tanggal, jam).
///
/// Satu tempat untuk semua tampilan nilai, agar tidak ada daftar hari/bulan
/// atau logika rupiah yang terduplikasi di banyak layar.
abstract final class AppFormat {
  static const _dayShort = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const _dayLong = [
    'Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu',
  ];
  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// 75000 -> "Rp75.000"
  static String rupiah(int value) {
    final digits = value.abs().toString();
    final buf = StringBuffer(value < 0 ? '-Rp' : 'Rp');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// 90 -> "01:30" (menit sejak tengah malam).
  static String hhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 125 -> "02:05" (detik -> mm:ss).
  static String clock(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// "16:00:00" -> 960 (menit sejak tengah malam).
  static int minutesOfTime(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// "16:00:00" -> "16:00".
  static String shortTime(String time) =>
      time.length >= 5 ? time.substring(0, 5) : time;

  /// "16:00", "18:00" -> "16:00–18:00".
  static String timeRange(String start, String end) =>
      '${shortTime(start)}–${shortTime(end)}';

  /// Nama hari panjang dari jam ketersediaan (0 = Minggu … 6 = Sabtu).
  static String longDayName(int dayOfWeek) => _dayLong[dayOfWeek % 7];

  /// "Sen, 5 Okt" dari DateTime.
  static String dateShort(DateTime d) =>
      '${_dayShort[d.weekday % 7]}, ${d.day} ${_monthShort[d.month - 1]}';

  /// "Sen, 5 Okt · 16:00" dari DateTime.
  static String dateTimeShort(DateTime d) =>
      '${dateShort(d)} · ${hhmm(d.hour * 60 + d.minute)}';
}
