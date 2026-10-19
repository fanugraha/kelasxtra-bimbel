import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../booking_repository.dart';

/// Catatan tutor untuk sesi ini: materi, perkembangan siswa, dan tugas/saran
/// berikutnya — tiap bagian satu baris berikon supaya mudah dipindai. Bila
/// belum ada, kartu menampilkan keadaan kosong dan (untuk tutor) tombol
/// mengisinya — karena `complete_booking` mewajibkan catatan, keadaan kosong
/// pada sesi selesai hanya muncul di sesi yang tuntas otomatis.
class SessionNoteCard extends StatelessWidget {
  const SessionNoteCard({
    super.key,
    required this.note,
    this.onEdit,
    this.emptyHint,
  });

  final SessionNote? note;

  /// Bila diisi (tutor), muncul tombol mengisi/mengubah catatan.
  final VoidCallback? onEdit;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final n = note;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Catatan tutor',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (n?.updatedAt != null)
                Text(
                  'Diperbarui ${AppFormat.dateShort(n!.updatedAt!)}',
                  style: theme.textTheme.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (n == null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 34,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Belum ada catatan', style: theme.textTheme.titleSmall),
                  if (emptyHint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      emptyHint!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            )
          else ...[
            _Section(
              icon: Icons.menu_book_rounded,
              label: 'Materi yang dibahas',
              value: n.material,
              bg: palette.brandSoft,
              fg: palette.brand,
            ),
            if (n.progress != null && n.progress!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _Section(
                icon: Icons.trending_up_rounded,
                label: 'Perkembangan siswa',
                value: n.progress!,
                bg: palette.successSoft,
                fg: palette.success,
              ),
            ],
            if (n.hasAssignment) ...[
              const SizedBox(height: AppSpacing.lg),
              _Assignment(value: n.nextStep!),
            ],
          ],
          if (onEdit != null) ...[
            const SizedBox(height: AppSpacing.lg),
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

/// Satu bagian catatan: ikon tonal di kiri, label kecil + isi di kanan.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: fg),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tugas/saran berikutnya: yang paling perlu ditindaklanjuti siswa, jadi
/// diberi blok tonal reward agar menonjol.
class _Assignment extends StatelessWidget {
  const _Assignment({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: palette.rewardSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_rounded, size: 18, color: palette.reward),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Tugas & saran berikutnya',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.reward,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
