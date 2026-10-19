import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kartu dasar aplikasi: sudut membulat, border halus, tanpa bayangan berat.
///
/// Pakai [gradient] untuk kartu unggulan (hero/CTA).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.gradient,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = AppRadius.card;

    final content = InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Padding(padding: padding, child: child),
    );

    if (gradient != null) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: radius,
        border: Border.all(color: scheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: content,
    );
  }
}
