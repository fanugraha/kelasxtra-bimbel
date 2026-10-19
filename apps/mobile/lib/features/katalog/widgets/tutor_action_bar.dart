import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../katalog_repository.dart';

/// Bar aksi bawah: satu tombol besar "Beli Paket" + harga mulai dari.
/// Chat dipindah ke tombol bulat di kanan atas profil.
class TutorActionBar extends StatelessWidget {
  const TutorActionBar({super.key, required this.detail});

  final TutorDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final price = detail.minPackagePrice;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Material(
          color: palette.brand,
          borderRadius: BorderRadius.circular(AppRadius.lg + 2),
          child: InkWell(
            onTap: () => context.push('/paket/beli/${detail.tutor.id}'),
            borderRadius: BorderRadius.circular(AppRadius.lg + 2),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Beli Paket',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: palette.onBrand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (price != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.onBrand.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'mulai ${AppFormat.rupiah(price)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: palette.onBrand,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
