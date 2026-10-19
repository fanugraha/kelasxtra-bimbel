import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
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
    final initial =
        tutor.fullName.isEmpty ? '?' : tutor.fullName[0].toUpperCase();
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
              CircleAvatar(
                radius: 32,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                backgroundImage: hasPhoto ? NetworkImage(tutor.photoUrl!) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        initial,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 15, color: AppColors.star),
                        const SizedBox(width: 3),
                        Text(
                          tutor.ratingAvg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          ' rating · $modeLabel',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11.5),
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
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
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
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    height: 1.1,
                    letterSpacing: -0.6,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '/ ${minPackageSesi ?? 4} pertemuan',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
