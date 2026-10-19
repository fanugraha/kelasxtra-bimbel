import 'package:bimbel_mobile/features/bank_soal/bank_soal_repository.dart';
import 'package:bimbel_mobile/features/home/siswa/mastery_data.dart';
import 'package:flutter_test/flutter_test.dart';

TopicStat _s(String topic, String subject, int att, int cor) => TopicStat(
  topicName: topic,
  subjectName: subject,
  attemptsCount: att,
  correctCount: cor,
  accuracy: cor * 100 / att,
  last20Correct: cor,
  last20Total: att,
);

void main() {
  test('nilai mapel = total benar / total soal, bukan rata-rata persen', () {
    final rows = subjectRows([
      _s('Kinematika', 'Fisika', 40, 32), // 80%
      _s('Dinamika', 'Fisika', 4, 1), // 25%, sedikit soal
    ]);
    // (32 + 1) / (40 + 4) = 75%, bukan (80 + 25) / 2 = 52,5%.
    expect(rows.single.accuracy, 75);
    expect(rows.single.caption, 'Terlemah: Dinamika 25%');
  });

  test('mapel urut kuat → lemah; mapel 1 topik menyebut topiknya', () {
    final rows = subjectRows([
      _s('Trigonometri', 'Matematika', 20, 6),
      _s('Stoikiometri', 'Kimia', 20, 18),
    ]);
    expect(rows.map((r) => r.name), ['Kimia', 'Matematika']);
    expect(rows.first.caption, 'Stoikiometri');
  });

  test('baris topik membawa nama mapel sebagai keterangan', () {
    final rows = topicRows([
      _s('Tenses', 'Bahasa Inggris', 20, 12),
      _s('Genetika', 'Biologi', 10, 9),
    ]);
    expect(rows.map((r) => r.name), ['Genetika', 'Tenses']);
    expect(rows.last.caption, 'Bahasa Inggris');
  });
}
