import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import 'widgets/math_text.dart';
import 'bank_soal_repository.dart';

class HasilScreen extends StatelessWidget {
  const HasilScreen({
    super.key,
    required this.result,
    required this.questions,
    this.title = 'Hasil Latihan',
  });

  final AttemptResult result;
  final Map<String, PracticeQuestion> questions;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final pct = result.total == 0
        ? 0
        : (result.correct * 100 / result.total).round();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            // Warna: nilai/skor = pencapaian → reward (emas), bukan brand.
            // Ujung kedua selalu digelapkan (mode gelap jadi lebih redup).
            // Kontras teks onReward di titik terterang (stop pertama):
            // terang putih/#9B661A 4.87:1, gelap #2A1E05/#F2C14E 9.73:1.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.reward,
                Color.lerp(palette.reward, Colors.black, 0.15)!,
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Nilaimu',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.onReward,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$pct',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: palette.onReward,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${result.correct} benar dari ${result.total} soal',
                  // Alpha penuh: putih 90% di #9B661A hanya 4.30:1.
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.onReward,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Pembahasan', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (final r in result.results)
            _ReviewCard(
              result: r,
              question: questions[r.questionId],
              index: result.results.indexOf(r) + 1,
            ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.result,
    required this.question,
    required this.index,
  });

  final QuestionResult result;
  final PracticeQuestion? question;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final color = result.isCorrect ? palette.success : palette.danger;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                result.isCorrect ? 'Benar' : 'Salah',
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
              const Spacer(),
              Text('Soal $index', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (question != null)
            MathText(question!.body, style: theme.textTheme.bodyLarge!),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Kunci: ${result.correctAnswer}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (result.explanation != null && result.explanation!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Pembahasan', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            MathText(result.explanation!, style: theme.textTheme.bodyMedium!),
          ],
          if (question?.imagePath != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('(soal ini punya gambar)', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
