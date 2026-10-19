import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';

/// Kartu satu isian di Beli Paket. [number] tampil sebagai lencana bulat
/// (berubah jadi centang saat [done]) supaya siswa tahu urutan & sisa isian.
class CheckoutSection extends StatelessWidget {
  const CheckoutSection({
    super.key,
    required this.title,
    required this.child,
    this.number,
    this.icon,
    this.hint,
    this.done = false,
    this.trailing,
  });

  final String title;
  final Widget child;
  final int? number;
  final IconData? icon;
  final String? hint;
  final bool done;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;

    Widget? badge;
    if (number != null) {
      badge = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done ? palette.success : palette.brandSoft,
          shape: BoxShape.circle,
        ),
        child: done
            ? Icon(Icons.check_rounded, size: 16, color: scheme.surface)
            : Text(
                '$number',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.brand,
                  fontWeight: FontWeight.w800,
                ),
              ),
      );
    } else if (icon != null) {
      badge = Icon(icon, size: 20, color: palette.brand);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (badge != null) ...[badge, const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: badge == null ? 0 : 36),
              child: Text(hint!, style: theme.textTheme.bodySmall),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Kartu pilihan besar (mapel, metode, jumlah pertemuan): ikon, judul,
/// keterangan, dan radio di kanan. Terpilih → garis & latar brand.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.trailing,
    this.badge,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  /// Teks kanan (mis. harga) — menggantikan radio.
  final Widget? trailing;

  /// Label kecil di samping judul (mis. "Hemat").
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;

    return Material(
      color: selected ? palette.brandSoft : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? palette.brand : scheme.outline,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected ? palette.brand : palette.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected ? palette.onBrand : palette.brand,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.promoSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: palette.promo,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              trailing ??
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 22,
                    color: selected ? palette.brand : scheme.outlineVariant,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indikator langkah di atas: titik bernomor tersambung garis.
class CheckoutStepper extends StatelessWidget {
  const CheckoutStepper({
    super.key,
    required this.current,
    this.labels = const ['Atur kelas', 'Ringkasan', 'Bayar'],
  });

  /// Indeks langkah aktif (0-based).
  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;

    Widget dot(int i) {
      final done = i < current;
      final active = i == current;
      return Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done
              ? palette.brand
              : active
              ? scheme.surface
              : scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
          border: Border.all(
            color: done || active ? palette.brand : scheme.outline,
            width: active ? 2.5 : 1,
          ),
        ),
        child: done
            ? Icon(Icons.check_rounded, size: 16, color: palette.onBrand)
            : Text(
                '${i + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: active ? palette.brand : scheme.onSurfaceVariant,
                ),
              ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              dot(i),
              if (i < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: i < current ? palette.brand : scheme.outline,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < labels.length; i++)
              Text(
                labels[i],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: i <= current ? scheme.onSurface : null,
                  fontWeight: i == current ? FontWeight.w700 : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Baris info ringkas: label kiri redup, nilai kanan tebal.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
