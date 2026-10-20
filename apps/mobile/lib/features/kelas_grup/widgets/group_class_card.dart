import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/person_photo.dart';
import '../kelas_grup_repository.dart';
import 'seat_row.dart';

/// Kartu program kelas grup; dipakai di daftar Belajar bareng dan tab Grup
/// di Cari. Isi: mapel + jenjang, tutor, jadwal tetap (mulai & jumlah
/// pertemuan), kursi visual, dan harga.
class GroupClassCard extends StatelessWidget {
  const GroupClassCard({super.key, required this.item});

  final GroupClassItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final c = item;
    final start = c.firstSession;
    final sisa = c.maxSeats - c.terisi;
    final (label, fg, bg) = !c.dibuka
        ? ('Kelas jalan', palette.success, palette.successSoft)
        : c.penuh && !c.tertahanSemua
        ? ('Penuh', scheme.onSurfaceVariant, scheme.surfaceContainerHigh)
        : sisa <= 2
        ? ('Sisa $sisa kursi', palette.warning, palette.warningSoft)
        : ('Dibuka', palette.info, palette.infoSoft);

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/kelas-grup/${c.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.brandSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      subjectIconFor(c.subjectName),
                      color: palette.brand,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.subjectName ?? 'Kelas grup',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${c.jenjang} · ${c.mode == 'online' ? 'Online' : 'Tatap muka'} · '
                          '${c.durationMinutes} menit',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  PersonPhoto(
                    name: c.tutorName ?? 'T',
                    photoUrl: c.tutorPhotoUrl,
                    subjectLine: c.subjectName,
                    size: 26,
                    radius: 13,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Tutor ${c.tutorName ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (c.tutorRating != null && c.tutorRating! > 0) ...[
                    Icon(Icons.star_rounded, size: 15, color: palette.reward),
                    Text(
                      c.tutorRating!.toStringAsFixed(1).replaceAll('.', ','),
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_repeat_rounded,
                      size: 17,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        start == null
                            ? '${c.totalSesi} pertemuan · jadwal menyusul'
                            : '${c.totalSesi} pertemuan · mulai '
                                  '${AppFormat.dateShort(start)}, ${AppFormat.hm(start)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SeatRow(
                          max: c.maxSeats,
                          paid: c.terisi,
                          held: c.seatsHeld,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${c.terisi}/${c.maxSeats} terisi · min. ${c.minSeats} agar jalan',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormat.rupiah(c.priceTotal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${AppFormat.rupiah(c.totalSesi == 0 ? c.priceTotal : c.priceTotal ~/ c.totalSesi)}/sesi',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
