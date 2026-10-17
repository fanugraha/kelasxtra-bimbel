import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/math_text.dart';
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
    final pct = result.total == 0 ? 0 : (result.correct * 100 / result.total).round();

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
            gradient: AppColors.gradient,
            child: Column(
              children: [
                Text('Nilaimu', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$pct',
                  style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${result.correct} benar dari ${result.total} soal',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
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
    final color = result.isCorrect ? AppColors.success : AppColors.danger;

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
          if (question != null) MathText(question!.body, style: theme.textTheme.bodyLarge!),
          const SizedBox(height: AppSpacing.sm),
          Text('Kunci: ${result.correctAnswer}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (result.explanation != null && result.explanation!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Pembahasan', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            MathText(result.explanation!, style: theme.textTheme.bodyMedium!),
          ],
          if (question?.imagePath != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('(soal ini punya gambar)',
                style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
