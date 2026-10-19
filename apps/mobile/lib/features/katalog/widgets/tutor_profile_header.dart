import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../katalog_repository.dart';

/// Bagian atas profil tutor: bar judul, foto besar, nama, ringkasan angka.
class TutorProfileHeader extends StatelessWidget {
  const TutorProfileHeader({
    super.key,
    required this.detail,
    required this.onChat,
  });

  final TutorDetail detail;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final t = detail.tutor;
    final modes = detail.availability.map((a) => a.mode).toSet();
    final modeLabel = modes.length > 1
        ? 'Online & Offline'
        : modes.contains('online')
        ? 'Online'
        : modes.contains('offline')
        ? 'Offline'
        : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _RoundButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Kembali',
              onTap: () => context.pop(),
            ),
            Expanded(
              child: Text(
                'Profil Tutor',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _RoundButton(
              icon: Icons.forum_outlined,
              tooltip: 'Chat tutor',
              onTap: onChat,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _Photo(tutor: t),
        const SizedBox(height: AppSpacing.lg),
        Text(
          t.fullName.isEmpty ? 'Tutor' : t.fullName,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: 6,
          children: [
            _Meta(
              icon: Icons.star_rounded,
              iconColor: palette.reward,
              label: 'Rating',
              value: t.ratingAvg.toStringAsFixed(1),
            ),
            _Meta(
              icon: Icons.menu_book_rounded,
              label: 'Mapel',
              value: '${{for (final s in detail.subjects) s.subjectId}.length}',
            ),
            _Meta(icon: Icons.laptop_mac_rounded, label: '', value: modeLabel),
          ],
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.brandSoft,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 19, color: palette.brand),
          ),
        ),
      ),
    );
  }
}

/// Foto besar bersudut membulat; tanpa foto → blok warna brand + inisial.
class _Photo extends StatelessWidget {
  const _Photo({required this.tutor});

  final TutorCatalogItem tutor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final url = tutor.photoUrl?.trim();
    final initial = tutor.fullName.trim().isEmpty
        ? '?'
        : tutor.fullName.trim()[0].toUpperCase();

    final fallback = ColoredBox(
      color: palette.brand,
      child: Center(
        child: Text(
          initial,
          style: theme.textTheme.displayLarge?.copyWith(
            color: palette.onBrand,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            fallback,
            if (url != null && url.isNotEmpty)
              Image.network(
                url,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.3),
                loadingBuilder: (c, child, p) =>
                    p == null ? child : const SizedBox.shrink(),
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              ),
            // Gradasi tipis di bawah supaya lencana tetap terbaca.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66000000)],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: AppPalette.light.brand,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tutor terverifikasi',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF1B2A30),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: iconColor ?? scheme.primary),
        const SizedBox(width: 5),
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
