import 'dart:io';

import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/bank_soal/bank_soal_repository.dart';
import 'package:bimbel_mobile/features/home/siswa/widgets/student_focus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TopicStat _s(String topic, String subject, int att, int cor, String trend) =>
    TopicStat(
      topicName: topic,
      subjectName: subject,
      attemptsCount: att,
      correctCount: cor,
      accuracy: cor * 100 / att,
      last20Correct: cor,
      last20Total: att,
      trend: trend,
    );

final _stats = [
  _s('Stoikiometri', 'Kimia', 20, 18, 'naik'),
  _s('Kinematika', 'Fisika', 25, 20, 'stabil'),
  _s('Genetika', 'Biologi', 36, 26, 'naik'),
  _s('Tenses', 'Bahasa Inggris', 20, 12, 'stabil'),
  _s('Kalkulus Dasar', 'Matematika', 24, 11, 'naik'),
  _s('Dinamika', 'Fisika', 20, 7, 'turun'),
  _s('Trigonometri', 'Matematika', 22, 6, 'turun'),
];

Widget _col(ThemeData theme) => Theme(
  data: theme,
  child: Builder(
    builder: (context) => Container(
      width: 390,
      color: theme.scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [StudentFocus(stats: _stats)],
      ),
    ),
  ),
);

void main() {
  testWidgets('preview kekuatan & kelemahan', (tester) async {
    tester.view.physicalSize = const Size(780, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_col(AppTheme.light()), _col(AppTheme.dark())],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/focus_preview.png'),
    );
  }, skip: !Platform.isMacOS);
}
