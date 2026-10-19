import 'package:flutter/material.dart';

import '../../../../core/mastery.dart';
import '../../../../core/theme/app_theme.dart';
import '../mastery_data.dart';

/// Grafik batang horizontal 0–100% (mapel atau topik), urut kuat → lemah.
/// Batang lebih panjang = lebih jago; warna + ikon = tingkatnya; garis
/// putus-putus = target. Ketuk baris untuk detail jumlah soal & tren.
///
/// [captionBelow]: keterangan baris ditaruh di bawah batang (untuk mapel,
/// "Terlemah: …"), bukan di samping nama (untuk topik, nama mapelnya).
class StrengthChart extends StatelessWidget {
  const StrengthChart({
    super.key,
    required this.rows,
    this.captionBelow = false,
  });

  final List<MasteryRow> rows;
  final bool captionBelow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...rows]..sort((a, b) => b.accuracy.compareTo(a.accuracy));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Legenda selalu ada (≥2 tingkat) — identitas tidak hanya dari warna.
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: 4,
          children: [
            for (final m in Mastery.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(m.icon, size: 14, color: m.color(context)),
                  const SizedBox(width: 4),
                  Text(
                    '${m.label} ${m.range}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final r in sorted) _BarRow(row: r, captionBelow: captionBelow),
        const SizedBox(height: 6),
        Row(
          children: [
            const _DashSample(),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Garis putus-putus = target ${masteryTarget.round()}%. '
                'Ketuk baris untuk detail.',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.row, required this.captionBelow});

  final MasteryRow row;
  final bool captionBelow;

  String get _detail {
    final trend = switch (row.trend) {
      'naik' => 'tren naik',
      'turun' => 'tren turun',
      'stabil' => 'tren stabil',
      _ => null,
    };
    return ['${row.correct} dari ${row.total} soal benar', ?trend].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = Mastery.of(row.accuracy);
    final color = m.color(context);
    final pct = row.accuracy.round();

    return Tooltip(
      message: '${row.name}: $_detail',
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: Padding(
        // Area sentuh lebih tinggi dari batangnya.
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(m.icon, size: 15, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!captionBelow && row.caption != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      row.caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
                const Spacer(),
                _TrendIcon(trend: row.trend),
                const SizedBox(width: 4),
                // Angka memakai warna teks, bukan warna seri.
                Text(
                  '$pct%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final fill = (row.accuracy / 100).clamp(0.0, 1.0) * w;
                final targetX = masteryTarget / 100 * w;
                return SizedBox(
                  height: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Lintasan 0–100%.
                      Positioned.fill(
                        top: 3,
                        bottom: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      // Batang nilai, ujung data membulat 4px.
                      Positioned(
                        left: 0,
                        top: 3,
                        bottom: 3,
                        width: fill < 4 ? 4 : fill,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      // Garis target.
                      Positioned(
                        left: targetX - 1,
                        top: 0,
                        bottom: 0,
                        child: const _DashLine(),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (captionBelow && row.caption != null) ...[
              const SizedBox(height: 4),
              Text(
                row.caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendIcon extends StatelessWidget {
  const _TrendIcon({required this.trend});

  final String? trend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (trend) {
      'naik' => Icons.trending_up_rounded,
      'turun' => Icons.trending_down_rounded,
      'stabil' => Icons.trending_flat_rounded,
      _ => null,
    };
    if (icon == null) return const SizedBox.shrink();
    return Tooltip(
      message: 'Tren $trend',
      child: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
    );
  }
}

/// Garis target vertikal putus-putus (2px), warna tinta sekunder.
class _DashLine extends StatelessWidget {
  const _DashLine();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: 2,
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Container(width: 2, height: 2.5, color: color),
            const SizedBox(height: 1.3),
          ],
        ],
      ),
    );
  }
}

class _DashSample extends StatelessWidget {
  const _DashSample();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 14, child: _DashLine());
}
