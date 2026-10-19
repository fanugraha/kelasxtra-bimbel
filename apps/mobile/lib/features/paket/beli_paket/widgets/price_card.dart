import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/widgets/price_summary.dart';
import '../../../katalog/katalog_repository.dart';
import '../../paket_providers.dart';

/// Blok harga paket: rincian (termasuk diskon voucher) + total.
class PriceCard extends ConsumerWidget {
  const PriceCard({
    super.key,
    required this.subject,
    required this.mode,
    required this.duration,
    required this.size,
    this.discount = 0,
    this.voucherCode,
  });

  final TutorSubjectItem? subject;
  final String? mode;
  final int duration;
  final int size;
  final int discount;
  final String? voucherCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subject == null || mode == null) {
      return const PriceSummaryCard(
        totalValue: null,
        emptyLabel: '—',
        footNote: 'Pilih mapel dan mode untuk melihat harga paket.',
      );
    }
    final price = ref.watch(
      packagePriceProvider((
        jenjang: subject!.jenjang,
        duration: duration,
        mode: mode!,
        totalSesi: size,
      )),
    );
    if (price.isLoading) {
      return const PriceSummaryCard(totalValue: null, loading: true);
    }
    final value = price.asData?.value;
    if (price.hasError || value == null) {
      return const PriceSummaryCard(
        totalValue: null,
        footNote: 'Harga paket belum diset admin untuk kombinasi ini.',
      );
    }
    final net = discount <= 0 ? value : (value - discount).clamp(0, value);
    final perSesi = paketPerSesi(net, size);
    return PriceSummaryCard(
      lines: [
        if (discount > 0)
          PriceLine.strike(
            '$size pertemuan × $duration menit',
            AppFormat.rupiah(value),
          )
        else
          PriceLine(
            '$size pertemuan × $duration menit',
            AppFormat.rupiah(value),
          ),
        if (discount > 0)
          PriceLine.discount(
            voucherCode == null || voucherCode!.isEmpty
                ? 'Voucher'
                : 'Voucher $voucherCode',
            '− ${AppFormat.rupiah(discount)}',
          ),
      ],
      totalValue: AppFormat.rupiah(net),
      totalNote: '$size pertemuan',
      footNote: perSesi == null
          ? null
          : 'Setara ${AppFormat.rupiah(perSesi)} per pertemuan · masa berlaku '
                '${paketMasaBerlaku(size)} sejak dibayar. Harga sudah termasuk biaya layanan.',
    );
  }
}
