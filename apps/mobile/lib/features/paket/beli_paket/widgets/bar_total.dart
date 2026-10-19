import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
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
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Total bayar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '$size pertemuan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (discount > 0) ...[
          Text(
            AppFormat.rupiah(value),
            style: theme.textTheme.labelSmall?.copyWith(
              // Warna: harga lama hanya pembanding → netral redup; warna promo
              // cukup di baris diskon.
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          AppFormat.rupiah(net),
          // Warna: total netral tebal — tombol bayar tetap satu-satunya
          // elemen brand yang paling menonjol.
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
