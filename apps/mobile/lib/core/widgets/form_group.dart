import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Label kecil di atas kelompok pilihan (mapel, durasi, hari, jumlah sesi …).
///
/// Dipakai seragam di wizard pesan sesi, beli paket, dan lembar filter supaya
/// hierarki teks sama di seluruh aplikasi:
/// judul langkah (25) → label kelompok (11, kapital) → pilihan (12) → catatan.
class FieldGroup extends StatelessWidget {
  const FieldGroup({
    super.key,
    required this.label,
    this.hint,
    this.trailing,
    required this.child,
  });

  final String label;
  final String? hint;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
        ],
        const SizedBox(height: AppSpacing.sm + 2),
        child,
      ],
    );
  }
}

/// Deretan pilihan yang membungkus otomatis — jarak antar chip selalu sama.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
}

/// Judul bagian berisi konten (bukan pilihan) — mis. "Tentang", "Jadwal".
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontSize: 16.5, letterSpacing: -0.2),
      );
}
