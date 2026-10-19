import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';

/// Satu aksi sekunder Detail sesi (ganti hari, komplain, tandai tidak hadir).
class SessionOption {
  const SessionOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  /// Aksi berisiko (laporan tidak hadir) → ikon & teks merah.
  final bool danger;
}

/// Daftar aksi yang jarang dipakai, dikumpulkan di bawah supaya tidak
/// bersaing dengan link kelas & catatan.
class SessionOptions extends StatelessWidget {
  const SessionOptions({super.key, required this.options, this.busy = false});

  final List<SessionOption> options;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.sm),
          child: Text(
            'Opsi lain',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.card,
            side: BorderSide(color: scheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 56, color: scheme.outline),
                ListTile(
                  enabled: !busy,
                  onTap: options[i].onTap,
                  leading: Icon(
                    options[i].icon,
                    color: options[i].danger
                        ? palette.danger
                        : scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    options[i].label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: options[i].danger ? palette.danger : null,
                    ),
                  ),
                  subtitle: options[i].subtitle == null
                      ? null
                      : Text(
                          options[i].subtitle!,
                          style: theme.textTheme.bodySmall,
                        ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
