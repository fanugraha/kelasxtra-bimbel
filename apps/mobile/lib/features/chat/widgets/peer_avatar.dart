import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Avatar bulat untuk lawan bicara chat (foto atau inisial nama).
class PeerAvatar extends StatelessWidget {
  const PeerAvatar({
    super.key,
    required this.name,
    required this.radius,
    this.avatar,
  });

  final String name;
  final double radius;
  final String? avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = avatar != null && avatar!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.palette.brandSoft,
      backgroundImage: hasPhoto ? NetworkImage(avatar!) : null,
      child: hasPhoto
          ? null
          : Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              // Ukuran mengikuti radius avatar (inisial = grafis, bukan teks
              // isi), jadi fontSize sengaja ditimpa.
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}
