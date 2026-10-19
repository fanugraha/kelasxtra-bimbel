import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../katalog_repository.dart';

/// Bar aksi bawah: beli paket dan chat tutor.
class TutorActionBar extends StatelessWidget {
  const TutorActionBar({super.key, required this.detail});

  final TutorDetail detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Beli Paket',
              icon: Icons.shopping_bag_outlined,
              onPressed: () => context.push('/paket/beli/${detail.tutor.id}'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Chat',
              icon: Icons.forum_outlined,
              variant: AppButtonVariant.ghost,
              onPressed: () => context.push(
                '/chat/room/${detail.tutor.id}',
                extra: {'name': detail.tutor.fullName},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
