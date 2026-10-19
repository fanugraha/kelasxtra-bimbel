import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final active = selected || onRemove != null;
    final removable = onRemove != null;

    return InkWell(
      // Chip yang bisa dilepas: seluruh badan chip juga berfungsi melepas,
      // supaya target sentuh tidak hanya ikon ✕ yang kecil.
      onTap: onTap ?? onRemove,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.only(
          left: 14,
          right: removable ? 6 : 14,
          top: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withValues(alpha: 0.11)
              : scheme.surface,
          border: Border.all(
            color: active
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
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
                    size: 14,
                    color: scheme.primary,
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
