/// Pemformatan bersama (uang, tanggal, jam).
///
/// Satu tempat untuk semua tampilan nilai, agar tidak ada daftar hari/bulan
/// atau logika rupiah yang terduplikasi di banyak layar.
abstract final class AppFormat {
  static const _dayShort = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const _dayLong = [
    'Minggu',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];
  static const _monthShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
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

  /// Nama hari pendek (0 = Minggu … 6 = Sabtu), mis. "Sen".
  static String shortDayName(int dayOfWeek) => _dayShort[dayOfWeek % 7];

  /// "Sen, 5 Okt" dari DateTime.
  static String dateShort(DateTime d) =>
      '${_dayShort[d.weekday % 7]}, ${d.day} ${_monthShort[d.month - 1]}';

  /// "5 Okt" dari DateTime — untuk blok jam yang sudah memuat nama hari.
  static String dateNumber(DateTime d) =>
      '${d.day} ${_monthShort[d.month - 1]}';

  /// "Okt" dari DateTime — label bulan di bawah angka tanggal.
  static String monthShort(DateTime d) => _monthShort[d.month - 1];

  /// "Sen, 5 Okt · 16:00" dari DateTime.
  static String dateTimeShort(DateTime d) =>
      '${dateShort(d)} · ${hhmm(d.hour * 60 + d.minute)}';

  /// "Sabtu, 17 Oktober" dari DateTime.
  static String dateLong(DateTime d) =>
      '${_dayLong[d.weekday % 7]}, ${d.day} ${_monthLong[d.month - 1]}';

  static const _monthLong = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// "Oktober 2026" dari DateTime — judul kelompok riwayat.
  static String monthLabel(DateTime d) =>
      '${_monthLong[d.month - 1]} ${d.year}';

  /// Label waktu untuk daftar chat: "09.30" (hari ini), "Kemarin",
  /// "Sen" (beberapa hari lalu), atau "18 Okt".
  static String chatStamp(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return hm(d);
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return _dayShort[d.weekday % 7];
    return '${d.day} ${_monthShort[d.month - 1]}';
  }

  /// "19.00" dari DateTime.
  static String hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

  /// Label ringkas: "Hari ini", "Besok", atau "Sen, 20 Okt".
  static String dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    return dateShort(d);
  }

  /// "19.00–20.30" dari waktu mulai + durasi.
  static String timeRangeFrom(DateTime start, int minutes) {
    final end = start.add(Duration(minutes: minutes));
    return '${hm(start)}–${hm(end)}';
  }
}
