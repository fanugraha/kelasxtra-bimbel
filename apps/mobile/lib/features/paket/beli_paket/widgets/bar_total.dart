import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../katalog/katalog_repository.dart';
import '../../paket_providers.dart';

/// Total bayar ringkas di bar bawah — selalu terlihat sejak langkah pertama.
class BarTotal extends ConsumerWidget {
  const BarTotal({
    super.key,
    required this.subject,
    required this.mode,
    required this.duration,
    required this.size,
    this.discount = 0,
  });

  final TutorSubjectItem subject;
  final String mode;
  final int duration;
  final int size;
  final int discount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final price = ref.watch(
      packagePriceProvider((
        jenjang: subject.jenjang,
        duration: duration,
        mode: mode,
        totalSesi: size,
      )),
    );
    final value = price.asData?.value;
    if (value == null) return const SizedBox.shrink();
    final net = discount <= 0 ? value : (value - discount).clamp(0, value);
    return Row(
      children: [
        Text(
          'Total bayar',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$size pertemuan',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
        const Spacer(),
        if (discount > 0) ...[
          Text(
            AppFormat.rupiah(value),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          AppFormat.rupiah(net),
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 17,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
