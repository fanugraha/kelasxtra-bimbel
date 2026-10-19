import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
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
    final (icon, color, label) = switch (phase) {
      PaymentPhase.checking => (
          Icons.hourglass_top_rounded,
          scheme.onSurfaceVariant,
          'Total tagihan'
        ),
      PaymentPhase.success => (
          Icons.check_circle_rounded,
          AppColors.success,
          'Dibayar'
        ),
      PaymentPhase.waiting => (
          Icons.schedule_rounded,
          AppColors.warning,
          'Total tagihan'
        ),
      PaymentPhase.failed => (
          Icons.error_rounded,
          AppColors.danger,
          'Tidak terbayar'
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
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amount == null ? '—' : AppFormat.rupiah(amount!),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 25,
                        height: 1.1,
                        letterSpacing: -0.6,
                        color: phase == PaymentPhase.success
                            ? AppColors.success
                            : phase == PaymentPhase.failed
                                ? AppColors.danger
                                : AppColors.primary,
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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
          children: [
            for (final r in rows) SummaryRow(label: r.$1, value: r.$2),
          ],
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
    final (icon, color, text) = switch (phase) {
      PaymentPhase.checking => (
          Icons.hourglass_top_rounded,
          scheme.onSurfaceVariant,
          'Status diperbarui otomatis beberapa detik setelah pembayaran masuk.'
        ),
      PaymentPhase.success => (
          Icons.celebration_rounded,
          AppColors.success,
          'Semua pertemuan sudah masuk ke menu Jadwal. Buka detail tiap sesi untuk '
              'chat tutor, absen, atau minta jadwal ulang bila perlu.'
        ),
      PaymentPhase.waiting => (
          Icons.info_outline_rounded,
          AppColors.warning,
          'Jadwalmu ditahan 30 menit sejak tagihan dibuat. Bila lewat, pesanan '
              'dibatalkan otomatis dan kamu bisa memilih jadwal lagi.'
        ),
      PaymentPhase.failed => (
          Icons.refresh_rounded,
          AppColors.danger,
          'Tidak ada dana yang terpotong. Silakan pilih ulang jadwal paketmu.'
        ),
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
