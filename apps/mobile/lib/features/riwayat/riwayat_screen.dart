import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import 'riwayat_providers.dart';
import 'riwayat_repository.dart';
import 'widgets/transaksi_tile.dart';

/// Riwayat uang siswa: pembelian paket, sesi satuan, langganan bank soal, dan
/// kursi kelas grup. Dipisah dari Jadwal supaya agenda sesi tetap ringkas.
class RiwayatScreen extends ConsumerWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riwayat = ref.watch(riwayatProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(riwayatProvider),
          child: AsyncView<List<TransaksiItem>>(
            value: riwayat,
            errorTitle: 'Gagal memuat riwayat transaksi',
            onRetry: () => ref.invalidate(riwayatProvider),
            builder: (list) => ListView(
              padding: screenPadding,
              children: [
                const ScreenHead(
                  showBack: true,
                  eyebrow: 'Keuangan',
                  title: 'Riwayat transaksi',
                  subtitle:
                      'Semua pembayaran paket, sesi, langganan, dan kelas grup.',
                ),
                const SizedBox(height: AppSpacing.xl),
                if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Belum ada transaksi',
                    message:
                        'Pembelian paket, langganan, dan kelas grup akan tercatat di sini.',
                  )
                else
                  ..._groupedByMonth(Theme.of(context), list),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dikelompokkan per bulan (terbaru dulu) agar mudah ditelusuri.
  List<Widget> _groupedByMonth(ThemeData theme, List<TransaksiItem> list) {
    final groups = <String, List<TransaksiItem>>{};
    for (final item in list) {
      groups.putIfAbsent(AppFormat.monthLabel(item.at), () => []).add(item);
    }

    return [
      for (final group in groups.values) ...[
        Text(
          AppFormat.monthLabel(group.first.at),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in group) ...[
          TransaksiTile(item: item),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.xs),
      ],
    ];
  }
}
