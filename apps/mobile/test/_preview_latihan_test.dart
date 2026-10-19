import 'dart:io';

import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/bank_soal/bank_soal_providers.dart';
import 'package:bimbel_mobile/features/bank_soal/bank_soal_repository.dart';
import 'package:bimbel_mobile/features/bank_soal/hasil_screen.dart';
import 'package:bimbel_mobile/features/bank_soal/latihan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PracticeQuestion _q(String id, String body, List<String> opts) =>
    PracticeQuestion(
      id: id,
      type: 'pg',
      version: 1,
      body: body,
      options: [
        for (var i = 0; i < opts.length; i++)
          QuestionOption(key: 'ABCD'[i], text: opts[i]),
      ],
    );

final _qs = [
  _q('1', 'Nilai limit x menuju 2 dari (x^2 - 4)/(x - 2) adalah ...', [
    '0',
    '2',
    '4',
    'tidak ada',
  ]),
  _q('2', 'Reaksi H2 + O2 -> H2O. Massa 0,5 mol H2SO4 (Mr = 98) adalah ...', [
    '49 g',
    '98 g',
    '196 g',
    '24,5 g',
  ]),
  _q('3', 'Nilai dari cos 120 derajat adalah ...', [
    '1/2',
    '-1/2',
    'akar3/2',
    '-akar3/2',
  ]),
];

class _FakeRepo extends BankSoalRepository {
  @override
  Future<({String attemptId, List<PracticeQuestion> questions})> startAttempt({
    required String mode,
    String? topicId,
    String? jenjang,
    int count = 10,
  }) async => (attemptId: 'a', questions: _qs);
}

void main() {
  testWidgets('preview mengerjakan soal + hasil', (tester) async {
    tester.view.physicalSize = const Size(780, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [bankSoalRepositoryProvider.overrideWithValue(_FakeRepo())],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Row(
            children: [
              const SizedBox(
                width: 390,
                child: LatihanScreen(topicId: 't', topicName: 'Trigonometri'),
              ),
              SizedBox(
                width: 390,
                child: HasilScreen(
                  result: const AttemptResult(
                    attemptId: 'a',
                    total: 3,
                    correct: 1,
                    results: [
                      QuestionResult(
                        questionId: '3',
                        isCorrect: false,
                        correctAnswer: 'B',
                        explanation:
                            'cos 120 = cos (180 - 60) = -cos 60 = -1/2.',
                      ),
                    ],
                  ),
                  questions: {for (final q in _qs) q.id: q},
                  answers: const {'3': 'D'},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Pindah ke soal 3, pilih C, tandai ragu-ragu.
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C').first);
    await tester.tap(find.text('Ragu-ragu'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('goldens/latihan_preview.png'),
    );
  }, skip: !Platform.isMacOS);
}
