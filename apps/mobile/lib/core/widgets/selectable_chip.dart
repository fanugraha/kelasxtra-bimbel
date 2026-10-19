import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Chip pilihan bergaya katalog — dipakai chip filter, chip di lembar filter,
/// dan chip "filter aktif". Isi `onRemove` untuk chip yang bisa dilepas (✕).
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final removable = onRemove != null;
    final active = selected;

    return InkWell(
      // Chip yang bisa dilepas: seluruh badan chip juga berfungsi melepas,
      // supaya target sentuh tidak hanya ikon ✕ yang kecil.
      onTap: onTap ?? onRemove,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.only(
          left: 15,
          right: removable ? 8 : 15,
          top: 9,
          bottom: 9,
        ),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary
              : removable
              ? palette.brandSoft
              : scheme.surface,
          border: Border.all(
            color: active
                ? scheme.primary
                : removable
                ? palette.brandSoft
                : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: active
                    ? scheme.onPrimary
                    : removable
                    ? palette.brand
                    : scheme.onSurfaceVariant,
              ),
            ),
            if (removable) ...[
              const SizedBox(width: 2),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: palette.brand,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
