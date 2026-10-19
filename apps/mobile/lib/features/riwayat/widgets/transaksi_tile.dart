import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../riwayat_repository.dart';

/// Satu baris riwayat transaksi: jenis, judul, nominal, dan status.
class TransaksiTile extends StatelessWidget {
  const TransaksiTile({super.key, required this.item});

  final TransaksiItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meta = _statusMeta(item);

    return AppCard(
      onTap: item.route == null ? null : () => context.push(item.route!),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon(item.kind), size: 19, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormat.dateShort(item.at),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (item.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormat.rupiah(item.amount),
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 5),
              StatusBadge(label: meta.label, tone: meta.tone),
            ],
          ),
        ],
      ),
    );
  }

  IconData _icon(TransaksiKind kind) => switch (kind) {
        TransaksiKind.paket => Icons.card_membership_rounded,
        TransaksiKind.sesi => Icons.event_available_rounded,
        TransaksiKind.langganan => Icons.menu_book_rounded,
        TransaksiKind.kelasGrup => Icons.groups_rounded,
      };

  /// Status berbeda antar sumber (payment Midtrans vs status paket/kursi).
  ({String label, StatusTone tone}) _statusMeta(TransaksiItem item) {
    final s = item.status;
    return switch (item.kind) {
      TransaksiKind.langganan => switch (s) {
          'active' => (label: 'Aktif', tone: StatusTone.success),
          'grace' => (label: 'Masa tenggang', tone: StatusTone.warning),
          'pending' => (label: 'Menunggu bayar', tone: StatusTone.warning),
          'expired' => (label: 'Berakhir', tone: StatusTone.neutral),
          _ => (label: s, tone: StatusTone.neutral),
        },
      TransaksiKind.sesi => switch (s) {
          'settlement' => (label: 'Lunas', tone: StatusTone.success),
          'pending' => (label: 'Menunggu bayar', tone: StatusTone.warning),
          'expire' => (label: 'Kedaluwarsa', tone: StatusTone.neutral),
          'deny' || 'cancel' => (label: 'Gagal', tone: StatusTone.danger),
          'refund' || 'partial_refund' => (
              label: 'Dana kembali',
              tone: StatusTone.neutral,
            ),
          _ => (label: s, tone: StatusTone.neutral),
        },
      TransaksiKind.paket || TransaksiKind.kelasGrup => switch (s) {
          'active' => (label: 'Lunas', tone: StatusTone.success),
          'pending_payment' => (label: 'Menunggu bayar', tone: StatusTone.warning),
          'refund_pending' => (
              label: 'Menunggu dana kembali',
              tone: StatusTone.warning,
            ),
          'refunded' => (label: 'Dana kembali', tone: StatusTone.neutral),
          'expired' => (label: 'Kedaluwarsa', tone: StatusTone.neutral),
          'cancelled' => (label: 'Dibatalkan', tone: StatusTone.danger),
          _ => (label: s, tone: StatusTone.neutral),
        },
    };
  }
}
