import 'dart:io';

import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/bank_soal/bank_soal_providers.dart';
import 'package:bimbel_mobile/features/bank_soal/bank_soal_repository.dart';
import 'package:bimbel_mobile/features/bank_soal/widgets/free_pack_card.dart';
import 'package:bimbel_mobile/features/bank_soal/widgets/subject_picker.dart';
import 'package:bimbel_mobile/features/bank_soal/widgets/subscription_card.dart';
import 'package:bimbel_mobile/features/bank_soal/widgets/topic_panel.dart';
import 'package:bimbel_mobile/features/bank_soal/widgets/tryout_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogTopic _t(String id, String name, int n) => CatalogTopic(
  topicId: id,
  topicName: name,
  subjectId: 'm',
  subjectName: 'Matematika',
  jenjang: 'SMA',
  questionCount: n,
);

final _topics = [
  _t('trig', 'Trigonometri', 10),
  _t('kal', 'Kalkulus Dasar', 5),
  _t('stat', 'Statistika', 0),
];

const _pack = QuestionPack(
  id: 'p',
  title: 'Paket Coba Gratis: Trigonometri',
  subjectName: 'Matematika',
  topicName: 'Trigonometri',
  jenjang: 'SMA',
  isFree: true,
  questionCount: 10,
  lastCorrect: 7,
  lastTotal: 10,
);

final _stats = {
  'trig': const TopicStat(
    topicName: 'Trigonometri',
    attemptsCount: 22,
    correctCount: 6,
    accuracy: 27,
    last20Correct: 6,
    last20Total: 20,
  ),
  'kal': const TopicStat(
    topicName: 'Kalkulus Dasar',
    attemptsCount: 24,
    correctCount: 20,
    accuracy: 83,
    last20Correct: 16,
    last20Total: 20,
  ),
};

const _subjects = <SubjectEntry>[
  (name: 'Matematika', topics: 3),
  (name: 'Fisika', topics: 2),
  (name: 'Biologi', topics: 1),
];

Widget _col({required bool sub}) => SizedBox(
  width: 390,
  child: ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (!sub) ...[
        FreePackCard(pack: _pack, onStart: () {}),
        const SizedBox(height: 12),
      ],
      SubscriptionCard(
        sub: sub
            ? SubscriptionInfo(
                status: 'active',
                currentPeriodEnd: DateTime(2026, 11, 18),
              )
            : null,
        buying: false,
        onBuy: () {},
      ),
      const SizedBox(height: 18),
      SubjectPicker(
        jenjangs: const ['SMP', 'SMA'],
        jenjang: 'SMA',
        onJenjang: (_) {},
        subjects: _subjects,
        selected: 'Matematika',
        onSelect: (_) {},
      ),
      const SizedBox(height: 12),
      TopicPanel(
        subject: 'Matematika',
        topics: _topics,
        stats: sub ? _stats : const {},
        unlocked: sub,
        freeTopicId: 'trig',
        onOpen: (_) {},
        onLocked: (_) {},
      ),
      const SizedBox(height: 18),
      TryoutHero(enabled: sub, onTap: () {}),
    ],
  ),
);

void main() {
  testWidgets('preview bank soal', (tester) async {
    tester.view.physicalSize = const Size(780, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planProvider.overrideWith(
            (ref) async => const PlanItem(
              code: 'bank_soal',
              name: 'Bank Soal',
              price: 49000,
              periodDays: 30,
              graceDays: 3,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_col(sub: false), _col(sub: true)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/bank_soal_preview.png'),
    );
  }, skip: !Platform.isMacOS);
}
