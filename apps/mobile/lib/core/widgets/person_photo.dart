import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class PersonPhoto extends StatelessWidget {
  const PersonPhoto({
    super.key,
    required this.name,
    this.photoUrl,
    this.subjectLine,
    this.size = 52,
    this.radius = 16,
    this.showVerified = false,
  });

  final String name;
  final String? photoUrl;
  final String? subjectLine;
  final double size;
  final double radius;
  final bool showVerified;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = photoUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Fallback(name: name, subjectLine: subjectLine, size: size),
            if (hasPhoto)
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const SizedBox.shrink(),
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            if (showVerified)
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surface,
                      width: size * 0.035,
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: size * 0.18,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.name,
    required this.subjectLine,
    required this.size,
  });

  final String name;
  final String? subjectLine;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final palette = context.palette;
    // Avatar = warna polos brand (bukan gradasi); inisial pakai onBrand agar
    // kontras benar di mode terang (putih di teal 4.85:1) & gelap.
    final fg = palette.onBrand;

    return DecoratedBox(
      decoration: BoxDecoration(color: palette.brand),
      child: Stack(
        children: [
          Positioned(
            right: -size * 0.35,
            top: -size * 0.35,
            child: Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Icon(
              subjectIconFor(subjectLine),
              size: size * 0.64,
              color: fg.withValues(alpha: 0.16),
            ),
          ),
          Center(
            child: Text(
              initial,
              // Ukuran ikut besar avatar (inisial dekoratif, bukan teks isi).
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: fg,
                fontSize: size * 0.38,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData subjectIconFor(String? subject) {
  final text = (subject ?? '').toLowerCase();
  if (text.contains('matematika') || text.contains('math')) {
    return Icons.functions_rounded;
  }
  if (text.contains('fisika') ||
      text.contains('kimia') ||
      text.contains('biologi') ||
      text.contains('ipa')) {
    return Icons.science_rounded;
  }
  if (text.contains('inggris') || text.contains('bahasa')) {
    return Icons.translate_rounded;
  }
  return Icons.menu_book_rounded;
}
