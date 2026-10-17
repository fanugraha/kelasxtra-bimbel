import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/math_text.dart';
import 'bank_soal_providers.dart';
import 'bank_soal_repository.dart';
import 'hasil_screen.dart';

/// Layar latihan: satu soal per layar, dinilai di server saat selesai.
class LatihanScreen extends ConsumerStatefulWidget {
  const LatihanScreen({
    super.key,
    required this.topicId,
    required this.topicName,
    this.jenjang,
    this.count = 10,
  });

  final String topicId;
  final String topicName;
  final String? jenjang;
  final int count;

  @override
  ConsumerState<LatihanScreen> createState() => _LatihanScreenState();
}

class _LatihanScreenState extends ConsumerState<LatihanScreen> {
  late Future<({String attemptId, List<PracticeQuestion> questions})> _future;
  final _answers = <String, String?>{};
  var _index = 0;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _start();
  }

  Future<({String attemptId, List<PracticeQuestion> questions})> _start() {
    return ref.read(bankSoalRepositoryProvider).startAttempt(
          mode: 'latihan',
          topicId: widget.topicId,
          jenjang: widget.jenjang,
          count: widget.count,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.topicName)),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Tidak bisa mulai latihan',
              message: snap.error.toString().replaceFirst('Exception: ', ''),
              action: OutlinedButton.icon(
                onPressed: () => setState(() => _future = _start()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            );
          }
          final data = snap.data!;
          if (data.questions.isEmpty) {
            return const EmptyState(
              icon: Icons.quiz_outlined,
              title: 'Belum ada soal',
            );
          }
          return _buildQuestion(data);
        },
      ),
    );
  }

  Widget _buildQuestion(
    ({String attemptId, List<PracticeQuestion> questions}) data,
  ) {
    final theme = Theme.of(context);
    final q = data.questions[_index];
    final last = _index == data.questions.length - 1;
    final answered = _answers.containsKey(q.id);

    return Column(
      children: [
        LinearProgressIndicator(value: (_index + 1) / data.questions.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Text(
                'Soal ${_index + 1} dari ${data.questions.length}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              MathText(q.body, style: theme.textTheme.titleMedium!),
              const SizedBox(height: AppSpacing.lg),
              if (q.type == 'pg')
                for (final o in q.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _OptionTile(
                      option: o,
                      selected: _answers[q.id] == o.key,
                      onTap: () => setState(() => _answers[q.id] = o.key),
                    ),
                  )
              else
                TextField(
                  decoration: const InputDecoration(hintText: 'Jawabanmu'),
                  onChanged: (v) => _answers[q.id] = v,
                ),
            ],
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              if (_index > 0)
                Expanded(
                  child: AppButton(
                    label: 'Sebelumnya',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => setState(() => _index--),
                  ),
                ),
              if (_index > 0) const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: last ? 'Selesai & nilai' : 'Lanjut',
                  loading: _submitting,
                  onPressed: (!answered && !last)
                      ? null
                      : (last ? () => _submit(data) : () => setState(() => _index++)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submit(
    ({String attemptId, List<PracticeQuestion> questions}) data,
  ) async {
    setState(() => _submitting = true);
    try {
      final result = await ref.read(bankSoalRepositoryProvider).submitAttempt(
            attemptId: data.attemptId,
            answers: _answers,
          );
      await ref.read(bankSoalRepositoryProvider).fetchMyStats(); // hangatkan cache
      if (!mounted) return;
      ref.invalidate(myStatsProvider);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HasilScreen(
            result: result,
            questions: {for (final q in data.questions) q.id: q},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final QuestionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AppColors.primary
                  : theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Text(
              option.key,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: MathText(option.text, style: theme.textTheme.bodyLarge!)),
        ],
      ),
    );
  }
}
