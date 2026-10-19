import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Penunjuk progres yang bisa ditekan untuk kembali ke langkah sebelumnya.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.current,
    required this.labels,
    required this.onTap,
  });

  final int current;
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: i < current ? () => onTap(i) : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= current ? scheme.primary : scheme.outline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${labels[current]} — langkah ${current + 1} dari ${labels.length}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}
