import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/booking/booking_providers.dart';
import '../format.dart';
import '../theme/app_palette.dart';
import 'app_card.dart';

/// Sakelar "pakai poin" untuk pemotongan pembayaran. Muncul hanya bila siswa
/// punya saldo poin; poin otomatis dipotong server sebanyak mungkin (maksimal
/// sebesar tagihan). 1 poin = Rp1.
class CreditToggle extends ConsumerWidget {
  const CreditToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.total,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Tagihan sebelum poin (untuk memperkirakan potongan); null bila belum tahu.
  final int? total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final balance = ref.watch(myCreditProvider).value ?? 0;
    if (balance <= 0) return const SizedBox.shrink();

    final used = total == null
        ? balance
        : (balance < total! ? balance : total!);
    return AppCard(
      padding: EdgeInsets.zero,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(Icons.savings_rounded, color: context.palette.reward),
        title: Text('Pakai poin', style: theme.textTheme.titleSmall),
        subtitle: Text(
          'Saldo ${AppFormat.rupiah(balance)} · potong '
          '${AppFormat.rupiah(used)} dari tagihan',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
