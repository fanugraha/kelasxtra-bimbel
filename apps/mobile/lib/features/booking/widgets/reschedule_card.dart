import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../booking_repository.dart';

/// Kartu permintaan ganti hari untuk sesi ini. Bila `isMine` pengaju sedang
/// menunggu (boleh dibatalkan sendiri); bila bukan, kartu meminta jawaban
/// (Terima/Tolak) sebelum batas waktu `respond_by`.
class RescheduleCard extends StatelessWidget {
  const RescheduleCard({
    super.key,
    required this.request,
    required this.isMine,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    this.busy = false,
  });

  final RescheduleRequest request;
  final bool isMine;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 17,
                color: isMine ? scheme.primary : scheme.tertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isMine
                      ? 'Menunggu persetujuan ganti hari'
                      : 'Permintaan ganti hari',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Row(
            label: isMine ? 'Dari jadwal' : 'Jadwal sekarang',
            value: AppFormat.dateTimeShort(request.fromAt),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Row(
            label: 'Diusulkan ke',
            value: AppFormat.dateTimeShort(request.toAt),
          ),
          if (request.reason != null && request.reason!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Row(label: 'Alasan', value: request.reason!),
          ],
          if (request.respondBy != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Batas jawaban: ${AppFormat.dateTimeShort(request.respondBy!)} WIB',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (isMine)
            AppButton(
              label: 'Batalkan pengajuan',
              variant: AppButtonVariant.ghost,
              loading: busy,
              onPressed: onCancel,
            )
          else
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Tolak',
                    variant: AppButtonVariant.secondary,
                    loading: busy,
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Terima',
                    loading: busy,
                    onPressed: onAccept,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
