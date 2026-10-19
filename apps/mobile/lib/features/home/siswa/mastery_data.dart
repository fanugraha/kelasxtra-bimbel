import '../../bank_soal/bank_soal_repository.dart';

/// Satu baris grafik penguasaan — bisa satu mapel atau satu topik.
class MasteryRow {
  const MasteryRow({
    required this.name,
    required this.correct,
    required this.total,
    this.caption,
    this.trend,
  });

  final String name;

  /// Keterangan kecil di samping/bawah nama (mapel untuk topik, atau
  /// "Terlemah: …" untuk mapel).
  final String? caption;
  final int correct;
  final int total;
  final String? trend;

  double get accuracy => total == 0 ? 0 : correct * 100 / total;
}

/// Baris per topik (urut kuat → lemah).
List<MasteryRow> topicRows(List<TopicStat> stats) {
  final rows = [
    for (final s in stats)
      MasteryRow(
        name: s.topicName,
        caption: s.subjectName,
        correct: s.correctCount,
        total: s.attemptsCount,
        trend: s.trend,
      ),
  ];
  rows.sort((a, b) => b.accuracy.compareTo(a.accuracy));
  return rows;
}

/// Baris per mapel (urut kuat → lemah). Nilai mapel = total benar ÷ total
/// soal di semua topiknya — bukan rata-rata persen antar topik, supaya topik
/// yang baru dicoba sedikit soal tidak menyeret nilai mapel. Bila mapel punya
/// ≥2 topik, keterangannya menyebut topik terlemah (agar rata-rata tidak
/// menyembunyikan topik yang jeblok).
List<MasteryRow> subjectRows(List<TopicStat> stats) {
  final bySubject = <String, List<TopicStat>>{};
  for (final s in stats) {
    bySubject.putIfAbsent(s.subjectName ?? 'Lainnya', () => []).add(s);
  }
  final rows = <MasteryRow>[];
  for (final e in bySubject.entries) {
    final topics = e.value;
    final correct = topics.fold<int>(0, (n, s) => n + s.correctCount);
    final total = topics.fold<int>(0, (n, s) => n + s.attemptsCount);
    String caption;
    if (topics.length == 1) {
      caption = topics.single.topicName;
    } else {
      final weakest = topics.reduce((a, b) => a.accuracy <= b.accuracy ? a : b);
      caption = 'Terlemah: ${weakest.topicName} ${weakest.accuracy.round()}%';
    }
    rows.add(
      MasteryRow(name: e.key, caption: caption, correct: correct, total: total),
    );
  }
  rows.sort((a, b) => b.accuracy.compareTo(a.accuracy));
  return rows;
}
