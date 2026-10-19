import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'bank_soal_repository.dart';
import 'widgets/math_text.dart';

/// Hasil latihan/tryout: nilai, ringkasan benar/salah/kosong, lalu
/// pembahasan per soal. Tiap pilihan ditandai: jawaban benar (hijau ✓) dan
/// jawaban siswa yang salah (merah ✗) — siswa tak perlu mencocokkan huruf.
class HasilScreen extends StatefulWidget {
  const HasilScreen({
    super.key,
    required this.result,
    required this.questions,
    this.answers = const {},
    this.title = 'Hasil Latihan',
  });

  final AttemptResult result;
  final Map<String, PracticeQuestion> questions;

  /// Jawaban siswa per id soal (null/kosong = tidak dijawab).
  final Map<String, String?> answers;
  final String title;

  @override
  State<HasilScreen> createState() => _HasilScreenState();
}

class _HasilScreenState extends State<HasilScreen> {
  var _wrongOnly = false;

  bool _blank(String id) {
    final a = widget.answers[id];
    return a == null || a.trim().isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final r = widget.result;
    final pct = r.total == 0 ? 0 : (r.correct * 100 / r.total).round();
    final blank = r.results.where((x) => _blank(x.questionId)).length;
    final wrong = r.total - r.correct - blank;
    final shown = [
      for (var i = 0; i < r.results.length; i++)
        if (!_wrongOnly || !r.results[i].isCorrect) (i + 1, r.results[i]),
    ];
    final message = pct >= 75
        ? 'Mantap! Kamu sudah kuat di sini.'
        : pct >= 50
        ? 'Lumayan! Cek pembahasan soal yang salah, ya.'
        : 'Tidak apa-apa, pelajari pembahasannya lalu coba lagi.';

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg + 2),
            decoration: BoxDecoration(
              // Warna: nilai = pencapaian → reward (emas).
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.reward,
                  Color.lerp(palette.reward, Colors.black, 0.15)!,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              children: [
                Text(
                  'Nilaimu',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.onReward,
                  ),
                ),
                Text(
                  '$pct',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: palette.onReward,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.onReward,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _Stat(value: r.correct, label: 'Benar'),
                    _Stat(value: wrong, label: 'Salah'),
                    _Stat(value: blank, label: 'Kosong'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pembahasan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilterChip(
                selected: _wrongOnly,
                onSelected: (v) => setState(() => _wrongOnly = v),
                label: Text('Salah saja (${r.total - r.correct})'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Semua jawabanmu benar!',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
          for (final (n, res) in shown) ...[
            _ReviewCard(
              number: n,
              result: res,
              question: widget.questions[res.questionId],
              answer: widget.answers[res.questionId],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Kembali ke Bank Soal'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = context.palette.onReward;
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              color: on,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: on)),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.number,
    required this.result,
    required this.question,
    required this.answer,
  });

  final int number;
  final QuestionResult result;
  final PracticeQuestion? question;
  final String? answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final q = question;
    final blank = answer == null || answer!.trim().isEmpty;
    final (color, icon, label) = result.isCorrect
        ? (palette.success, Icons.check_circle_rounded, 'Benar')
        : blank
        ? (
            scheme.onSurfaceVariant,
            Icons.remove_circle_outline,
            'Tidak dijawab',
          )
        : (palette.danger, Icons.cancel_rounded, 'Salah');
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: scheme.onSurface,
      height: 1.5,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Soal $number',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (q != null) MathText(q.body, style: textStyle),
          const SizedBox(height: AppSpacing.md),
          if (q != null && q.type == 'pg')
            for (final o in q.options)
              _ReviewOption(
                option: o,
                correct: o.key == result.correctAnswer,
                picked: o.key == answer,
              )
          else ...[
            _AnswerLine(
              label: 'Jawabanmu',
              value: blank ? '—' : answer!,
              color: result.isCorrect ? palette.success : palette.danger,
            ),
            _AnswerLine(
              label: 'Jawaban benar',
              value: result.correctAnswer,
              color: palette.success,
            ),
          ],
          if (result.explanation != null &&
              result.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.infoSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        size: 17,
                        color: palette.info,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pembahasan',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: palette.info,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  MathText(
                    result.explanation!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewOption extends StatelessWidget {
  const _ReviewOption({
    required this.option,
    required this.correct,
    required this.picked,
  });

  final QuestionOption option;
  final bool correct;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final wrongPick = picked && !correct;
    final Color? bg = correct
        ? palette.successSoft
        : wrongPick
        ? palette.dangerSoft
        : null;
    final Color edge = correct
        ? palette.success
        : wrongPick
        ? palette.danger
        : scheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: edge),
        ),
        child: Row(
          children: [
            Text(
              option.key,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MathText(
                option.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (correct || picked) ...[
              const SizedBox(width: 6),
              Text(
                correct ? (picked ? 'Jawabanmu ✓' : 'Benar') : 'Jawabanmu',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: correct ? palette.success : palette.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: MathText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
