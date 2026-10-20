import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../kelas_grup/kelas_grup_providers.dart';
import '../../widgets/section_head.dart';

/// Pintu masuk tetap ke produk Kelas Grup di Beranda: satu kelas terdekat
/// supaya siswa tidak bergantung pada banner promo yang berputar.
class GroupClassSection extends ConsumerWidget {
  const GroupClassSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(groupClassesProvider).value ?? const [];
    if (classes.isEmpty) return const SizedBox.shrink();

    final item = classes.first;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final mulai = item.firstSession == null
        ? 'Jadwal menyusul'
        : AppFormat.dateShort(item.firstSession!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHead(
          title: 'Kelas grup',
          actionLabel: 'Lihat semua',
          onAction: () => context.push('/kelas-grup'),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          onTap: () => context.push('/kelas-grup/${item.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.brandSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      size: 22,
                      color: palette.brand,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subjectName ?? 'Kelas grup',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.tutorName ?? 'Tutor'} · ${item.jenjang} · '
                          '${item.mode == 'online' ? 'Online' : 'Offline'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (item.discountPercent > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.promoSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Hemat ${item.discountPercent}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.promo,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: palette.infoSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 16,
                      color: palette.info,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mulai $mulai · ${item.totalSesi} pertemuan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.event_seat_rounded,
                      size: 15,
                      color: palette.info,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sisa ${item.sisaKursi} kursi',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.info,
                        fontWeight: FontWeight.w700,
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
                        Text(
                          AppFormat.rupiah(item.pricePerSession),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'per sesi · total ${AppFormat.rupiah(item.priceTotal)}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Lihat kelas',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
