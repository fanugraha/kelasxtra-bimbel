/// Apakah dua waktu jatuh pada tanggal yang sama (zona waktu perangkat).
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
