import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/price_summary.dart';

/// Tahapan hasil pembayaran.
enum PaymentPhase { checking, success, waiting, failed }

/// Kartu utama status pembayaran: ikon, nominal, dan ID pembayaran.
class PaymentStatusHero extends StatelessWidget {
  const PaymentStatusHero({
    super.key,
    required this.phase,
    required this.amount,
    required this.orderId,
  });

  final PaymentPhase phase;
  final int? amount;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final (icon, color, soft, label) = switch (phase) {
      PaymentPhase.checking => (
        Icons.hourglass_top_rounded,
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
        'Total tagihan',
      ),
      PaymentPhase.success => (
        Icons.check_circle_rounded,
        palette.success,
        palette.successSoft,
        'Dibayar',
      ),
      PaymentPhase.waiting => (
        Icons.schedule_rounded,
        palette.warning,
        palette.warningSoft,
        'Total tagihan',
      ),
      PaymentPhase.failed => (
        Icons.error_rounded,
        palette.danger,
        palette.dangerSoft,
        'Tidak terbayar',
      ),
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      amount == null ? '—' : AppFormat.rupiah(amount!),
                      // Warna: nominal selalu netral tebal; status sudah
                      // diwakili ikon berwarna di sebelahnya.
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: scheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('ID pembayaran', style: theme.textTheme.bodySmall),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SelectableText(
                  orderId,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu rincian pembayaran (jenis, tutor, jadwal, dsb.).
class PaymentDetailCard extends StatelessWidget {
  const PaymentDetailCard({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [for (final r in rows) SummaryRow(label: r.$1, value: r.$2)],
    ),
  );
}

/// Kartu petunjuk langkah berikutnya sesuai tahap pembayaran.
class PaymentNextStepCard extends StatelessWidget {
  const PaymentNextStepCard({super.key, required this.phase});

  final PaymentPhase phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final (icon, color, text) = switch (phase) {
      PaymentPhase.checking => (
        Icons.hourglass_top_rounded,
        scheme.onSurfaceVariant,
        'Status diperbarui otomatis beberapa detik setelah pembayaran masuk.',
      ),
      PaymentPhase.success => (
        Icons.celebration_rounded,
        palette.success,
        'Semua pertemuan sudah masuk ke menu Jadwal. Buka detail tiap sesi untuk '
            'chat tutor, absen, atau minta jadwal ulang bila perlu.',
      ),
      PaymentPhase.waiting => (
        Icons.info_outline_rounded,
        palette.warning,
        'Jadwalmu ditahan 30 menit sejak tagihan dibuat. Bila lewat, pesanan '
            'dibatalkan otomatis dan kamu bisa memilih jadwal lagi.',
      ),
      PaymentPhase.failed => (
        Icons.refresh_rounded,
        palette.danger,
        'Tidak ada dana yang terpotong. Silakan pilih ulang jadwal paketmu.',
      ),
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
