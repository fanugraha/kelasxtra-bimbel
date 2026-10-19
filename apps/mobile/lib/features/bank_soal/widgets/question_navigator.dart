import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';

/// Status satu nomor soal saat mengerjakan.
enum QuestionState { belum, dijawab, ragu }

Color _fill(BuildContext context, QuestionState s) {
  final palette = context.palette;
  return switch (s) {
    QuestionState.dijawab => palette.brand,
    QuestionState.ragu => palette.warning,
    QuestionState.belum => Theme.of(context).colorScheme.surfaceContainerHigh,
  };
}

/// Strip progres: satu segmen per nomor (dijawab = brand, ragu = oranye,
/// belum = abu); nomor aktif lebih tebal. Ketuk segmen untuk lompat.
/// Lebih dari 25 soal → satu bilah progres biasa agar segmen tidak terlalu
/// tipis untuk disentuh.
class ProgressStrip extends StatelessWidget {
  const ProgressStrip({
    super.key,
    required this.states,
    required this.current,
    required this.onTap,
  });

  final List<QuestionState> states;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (states.length > 25) {
      final done = states.where((s) => s != QuestionState.belum).length;
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: done / states.length,
          minHeight: 6,
          backgroundColor: scheme.surfaceContainerHigh,
        ),
      );
    }
    return SizedBox(
      height: 14,
      child: Row(
        children: [
          for (var i = 0; i < states.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: i == current ? 8 : 5,
                    decoration: BoxDecoration(
                      color: _fill(context, states[i]),
                      borderRadius: BorderRadius.circular(4),
                      border: i == current
                          ? Border.all(color: scheme.onSurface, width: 1.2)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lembar "Daftar soal": kisi nomor berwarna + legenda; ketuk nomor untuk
/// lompat (mengembalikan indeksnya). Tombol bawah memicu [onFinish].
Future<int?> showQuestionNavigator(
  BuildContext context, {
  required List<QuestionState> states,
  required int current,
  required VoidCallback onFinish,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      final palette = ctx.palette;
      int count(QuestionState s) => states.where((x) => x == s).length;

      Widget legend(QuestionState s, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _fill(ctx, s),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text('$label (${count(s)})', style: theme.textTheme.labelMedium),
        ],
      );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Daftar soal',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: 6,
                children: [
                  legend(QuestionState.dijawab, 'Dijawab'),
                  legend(QuestionState.ragu, 'Ragu-ragu'),
                  legend(QuestionState.belum, 'Belum'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (var i = 0; i < states.length; i++)
                      Material(
                        color: _fill(ctx, states[i]),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: i == current
                              ? BorderSide(color: scheme.onSurface, width: 2)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => Navigator.pop(ctx, i),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: switch (states[i]) {
                                  QuestionState.dijawab => palette.onBrand,
                                  QuestionState.ragu => scheme.surface,
                                  QuestionState.belum => scheme.onSurface,
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onFinish();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  backgroundColor: palette.challenge,
                  foregroundColor: palette.onChallenge,
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Selesai & lihat nilai'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
