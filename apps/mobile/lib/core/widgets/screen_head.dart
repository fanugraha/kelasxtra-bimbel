import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Kepala layar sesuai desain mobile: eyebrow, judul besar, subjudul, dan
/// tombol kembali opsional.
class ScreenHead extends StatelessWidget {
  const ScreenHead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack) ...[
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: scheme.surface,
                foregroundColor: scheme.onSurface,
                side: BorderSide(color: scheme.outline),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 3,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        eyebrow.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(title, style: theme.textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Tombol ikon 44px bergaya desain (notifikasi, tema).
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.dot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: scheme.surface,
          shape: CircleBorder(side: BorderSide(color: scheme.outline)),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20),
                if (dot)
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: scheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol kecil untuk aksi di kanan judul seksi ("Semua", "Lihat").
class TextLink extends StatelessWidget {
  const TextLink({super.key, required this.label, this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 40),
        textStyle: theme.textTheme.labelMedium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (icon != null) ...[const SizedBox(width: 3), Icon(icon, size: 16)],
        ],
      ),
    );
  }
}

/// Padding standar isi layar (16px horizontal).
const screenPadding = EdgeInsets.fromLTRB(16, 0, 16, 36);

/// Padding sisi (16px) untuk anak ListView.
const screenSide = EdgeInsets.symmetric(horizontal: 16);

/// Bungkus anak ListView dengan padding sisi. Layar yang punya bagian
/// menggeser mendatar (karusel, deretan chip) memakai
/// `padding: EdgeInsets.only(bottom: 36)` di ListView-nya lalu membungkus anak
/// biasa dengan ini — supaya bagian mendatar itu bisa menyentuh tepi layar
/// dan tidak terpotong di batas margin.
Widget sidePad(Widget child) => Padding(padding: screenSide, child: child);
