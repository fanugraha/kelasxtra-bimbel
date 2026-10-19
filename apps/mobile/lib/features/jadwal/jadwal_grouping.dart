import '../booking/booking_repository.dart';

/// Status yang sudah tidak akan berjalan lagi → masuk riwayat kelas.
const _history = {'completed', 'cancelled', 'refunded'};

/// Belum lunas / kedaluwarsa tidak pernah tampil di Jadwal.
const _hidden = {'pending_payment', 'expired'};

/// Satu lawan belajar di tab Jadwal: tutor (aplikasi siswa) atau siswa
/// (aplikasi tutor), beserta sesi mendatang dan riwayat kelasnya.
class JadwalPerson {
  const JadwalPerson({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.subjects,
    required this.upcoming,
    required this.history,
  });

  final String id;
  final String name;
  final String? photoUrl;

  /// Mapel unik, urut dari yang paling sering.
  final List<String> subjects;

  /// Urut dari yang terdekat.
  final List<BookingItem> upcoming;

  /// Urut dari yang terbaru.
  final List<BookingItem> history;

  BookingItem? get next => upcoming.isEmpty ? null : upcoming.first;

  BookingItem? get last => history.isEmpty ? null : history.first;

  int get completedCount =>
      history.where((b) => b.status == 'completed').length;

  /// Total jam belajar dari sesi yang benar-benar selesai.
  double get completedHours =>
      history
          .where((b) => b.status == 'completed')
          .fold<int>(0, (sum, b) => sum + b.durationMinutes) /
      60;
}

/// Kelompokkan booking per tutor/siswa, lalu urutkan: yang punya sesi paling
/// dekat di atas; yang tinggal riwayat di bawah, dari yang terakhir bertemu.
List<JadwalPerson> groupJadwal(List<BookingItem> all, {required bool isSiswa}) {
  final byId = <String, List<BookingItem>>{};
  for (final b in all) {
    if (_hidden.contains(b.status)) continue;
    byId.putIfAbsent(isSiswa ? b.tutorId : b.studentId, () => []).add(b);
  }

  final people = [
    for (final e in byId.entries) _person(e.key, e.value, isSiswa),
  ];

  people.sort((a, b) {
    final an = a.next?.scheduledAt;
    final bn = b.next?.scheduledAt;
    if (an != null && bn != null) return an.compareTo(bn);
    if (an != null) return -1;
    if (bn != null) return 1;
    final al = a.last?.scheduledAt;
    final bl = b.last?.scheduledAt;
    if (al == null || bl == null) return a.name.compareTo(b.name);
    return bl.compareTo(al);
  });
  return people;
}

JadwalPerson _person(String id, List<BookingItem> items, bool isSiswa) {
  final upcoming = items.where((b) => !_history.contains(b.status)).toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  final history = items.where((b) => _history.contains(b.status)).toList()
    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  final freq = <String, int>{};
  for (final b in items) {
    freq[b.subjectName] = (freq[b.subjectName] ?? 0) + 1;
  }
  final subjects = freq.keys.toList()
    ..sort((a, b) => freq[b]!.compareTo(freq[a]!));

  final any = items.first;
  return JadwalPerson(
    id: id,
    name: isSiswa ? any.tutorName : any.studentName,
    photoUrl: isSiswa
        ? items
              .map((b) => b.tutorPhotoUrl)
              .firstWhere((u) => u != null, orElse: () => null)
        : null,
    subjects: subjects,
    upcoming: upcoming,
    history: history,
  );
}
