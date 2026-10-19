import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = avatar != null && avatar!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withValues(alpha: 0.11),
      backgroundImage: hasPhoto ? NetworkImage(avatar!) : null,
      child: hasPhoto
          ? null
          : Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}
