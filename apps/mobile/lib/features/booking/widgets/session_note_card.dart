import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../booking_repository.dart';

/// Catatan tentor untuk sesi ini: materi, perkembangan siswa, dan tugas/saran
/// berikutnya. Bila belum ada, kartu menampilkan keadaan kosong dan (untuk
/// tentor) tombol untuk mengisinya — karena `complete_booking` mewajibkan
/// catatan, keadaan kosong hanya muncul di sesi yang tuntas otomatis.
class SessionNoteCard extends StatelessWidget {
  const SessionNoteCard({
    super.key,
    required this.note,
    this.onEdit,
    this.emptyHint,
  });

  final SessionNote? note;

  /// Bila diisi (tentor), muncul tombol mengisi/mengubah catatan.
  final VoidCallback? onEdit;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = note;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 17,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Catatan tentor',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5),
                ),
              ),
              if (n?.updatedAt != null)
                Text(
                  AppFormat.dateShort(n!.updatedAt!),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (n == null) ...[
            Text(
              'Belum ada catatan dari tentor.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (emptyHint != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                emptyHint!,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],
          ] else ...[
            _Field(label: 'Materi', value: n.material),
            if (n.progress != null && n.progress!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _Field(label: 'Perkembangan siswa', value: n.progress!),
            ],
            if (n.hasAssignment) ...[
              const SizedBox(height: AppSpacing.md),
              _Field(
                label: 'Tugas atau saran berikutnya',
                value: n.nextStep!,
                highlight: true,
              ),
            ],
          ],
          if (onEdit != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: n == null ? 'Isi catatan sesi' : 'Ubah catatan sesi',
              icon: Icons.edit_note_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onEdit,
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primary.withValues(alpha: 0.07)
            : scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        border: Border.all(
          color: highlight
              ? scheme.primary.withValues(alpha: 0.25)
              : scheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: highlight ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
