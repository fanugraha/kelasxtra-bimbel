import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// Peran warna satu baris rincian harga.
enum PriceTone {
  /// Harga biasa — informasi, bukan ajakan.
  neutral,

  /// Diskon, voucher, potongan promo.
  promo,

  /// Potongan dari poin milik siswa.
  reward,
}

/// Satu baris rincian harga.
class PriceLine {
  const PriceLine(
    this.label,
    this.value, {
    this.tone = PriceTone.neutral,
    this.strike = false,
  });

  /// Baris "harga normal" yang dicoret saat ada diskon.
  const PriceLine.strike(this.label, this.value)
    : tone = PriceTone.neutral,
      strike = true;

  /// Baris diskon/voucher (promo).
  const PriceLine.discount(this.label, this.value)
    : tone = PriceTone.promo,
      strike = false;

  /// Baris potongan poin (reward).
  const PriceLine.points(this.label, this.value)
    : tone = PriceTone.reward,
      strike = false;

  final String label;
  final String value;
  final PriceTone tone;
  final bool strike;
}

/// Blok harga: rincian di atas, total besar di bawah garis pemisah.
///
/// Dipakai di wizard pesan sesi, beli paket, dan layar status pembayaran agar
/// angka uang selalu tampil dengan susunan yang sama.
class PriceSummaryCard extends StatelessWidget {
  const PriceSummaryCard({
    super.key,
    this.lines = const [],
    this.totalLabel = 'Total bayar',
    required this.totalValue,
    this.totalNote,
    this.footNote,
    this.emptyLabel = 'Harga belum diset',
    this.loading = false,
  });

  final List<PriceLine> lines;
  final String totalLabel;
  final String? totalValue;
  final String? totalNote;
  final String? footNote;

  /// Ditampilkan saat [totalValue] null (harga belum diketahui).
  final String emptyLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    Color? toneColor(PriceLine line) => switch (line.tone) {
      PriceTone.promo => palette.promo,
      PriceTone.reward => palette.reward,
      // Harga coret diredam agar mata langsung ke total.
      PriceTone.neutral =>
        line.strike ? theme.colorScheme.onSurfaceVariant : null,
    };

    if (loading) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 18,
              width: double.infinity,
              child: LinearProgressIndicator(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Menghitung harga…', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    line.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: toneColor(line),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  line.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: toneColor(line) ?? theme.colorScheme.onSurface,
                    decoration: line.strike ? TextDecoration.lineThrough : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (lines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Divider(height: 1, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(totalLabel, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  totalValue ?? emptyLabel,
                  style: theme.textTheme.displaySmall?.copyWith(
                    // Warna: total netral — informasi, tidak boleh menyaingi
                    // tombol bayar yang memakai warna brand.
                    color: theme.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (totalNote != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(totalNote!, style: theme.textTheme.labelSmall),
                ),
            ],
          ),
          if (footNote != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(footNote!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Baris ringkasan "label — nilai" untuk layar ringkasan/langkah akhir.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(value, style: theme.textTheme.titleSmall)),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 32),
                textStyle: theme.textTheme.labelMedium,
              ),
              child: const Text('Ubah'),
            ),
        ],
      ),
    );
  }
}
