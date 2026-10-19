import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// Satu baris rincian harga.
class PriceLine {
  const PriceLine(
    this.label,
    this.value, {
    this.tone,
    this.strike = false,
  });

  /// Baris "harga normal" yang dicoret saat ada diskon.
  PriceLine.strike(this.label, this.value)
      : tone = null,
        strike = true;

  /// Baris diskon (hijau).
  PriceLine.discount(this.label, this.value)
      : tone = AppColors.success,
        strike = false;

  final String label;
  final String value;
  final Color? tone;
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
                      fontSize: 12.5,
                      color: line.tone,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  line.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: line.tone,
                    decoration:
                        line.strike ? TextDecoration.lineThrough : null,
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
          Text(
            totalLabel,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  totalValue ?? emptyLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 25,
                    height: 1.1,
                    letterSpacing: -0.6,
                    color: totalValue == null ? null : AppColors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (totalNote != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    totalNote!,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ),
            ],
          ),
          if (footNote != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              footNote!,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
            ),
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
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Ubah'),
            ),
        ],
      ),
    );
  }
}
