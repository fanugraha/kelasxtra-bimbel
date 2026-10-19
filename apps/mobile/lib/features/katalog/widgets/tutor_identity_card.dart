import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../katalog_repository.dart';

/// Kartu identitas: avatar, ringkasan mapel, rating, dan harga paket terendah.
class TutorIdentityCard extends StatelessWidget {
  const TutorIdentityCard({
    super.key,
    required this.tutor,
    required this.modes,
    this.minPackagePrice,
    this.minPackageSesi,
  });

  final TutorCatalogItem tutor;
  final Set<String> modes;
  final int? minPackagePrice;
  final int? minPackageSesi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final initial = tutor.fullName.isEmpty
        ? '?'
        : tutor.fullName[0].toUpperCase();
    final hasPhoto = tutor.photoUrl != null && tutor.photoUrl!.isNotEmpty;
    final modeLabel = modes.length > 1
        ? 'Online & Offline'
        : modes.contains('online')
        ? 'Online'
        : modes.contains('offline')
        ? 'Offline'
        : 'Mode belum diatur';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.brandSoft,
                  borderRadius: BorderRadius.circular(22),
                  image: hasPhoto
                      ? DecorationImage(
                          image: NetworkImage(tutor.photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasPhoto
                    ? null
                    : Text(
                        initial,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: palette.brand,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutor.subjectLine.isEmpty
                          ? 'Mapel belum diisi'
                          : tutor.subjectLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Rating = REWARD.
                        Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: palette.reward,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          tutor.ratingAvg.toStringAsFixed(1),
                          style: theme.textTheme.titleSmall,
                        ),
                        Flexible(
                          child: Text(
                            ' rating · $modeLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: scheme.outline),
          const SizedBox(height: AppSpacing.md),
          Text(
            'MULAI DARI',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          if (minPackagePrice == null)
            Text('Harga paket belum diset', style: theme.textTheme.bodySmall)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  AppFormat.rupiah(minPackagePrice!),
                  style: theme.textTheme.displaySmall?.copyWith(
                    // Warna: harga netral — tidak menyaingi tombol pesan.
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '/ ${minPackageSesi ?? 4} pertemuan',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
