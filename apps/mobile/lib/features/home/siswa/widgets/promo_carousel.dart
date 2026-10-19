import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Karusel kartu promo di home siswa (tryout, paket, kelas grup).
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  /// 0.94 dari lebar layar (dikurangi inset kiri 20) ≈ lebar isi kartu, jadi
  /// kartu berikutnya hanya menyembul sedikit di tepi kanan layar — tidak
  /// terpotong di batas margin.
  final _controller = PageController(viewportFraction: 0.94);
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _PromoData(
        kicker: 'Tryout · Matematika SMA',
        title: 'Uji kesiapanmu dalam 5 menit',
        meta: '5 soal contoh · dinilai otomatis',
        action: 'Mulai tryout',
        icon: Icons.timer_outlined,
        onTap: () => context.push('/tryout'),
        primary: true,
      ),
      _PromoData(
        kicker: 'Paket sesi',
        title: 'Tambah 8 sesi, hemat 5%',
        meta: 'Berlaku 90 hari · semua tutor',
        action: 'Lihat paket',
        icon: Icons.workspace_premium_outlined,
        onTap: () => context.push('/paket'),
      ),
      const _PromoData(
        kicker: 'Kelas grup',
        title: 'Belajar bareng teman',
        meta: 'Kuota 3–5 siswa · harga lebih ringan',
        action: 'Cari kelas',
        icon: Icons.groups_outlined,
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 154,
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final card = cards[i];
                return Padding(
                  padding: EdgeInsets.only(
                    right: i == cards.length - 1 ? 0 : AppSpacing.sm,
                  ),
                  child: _PromoCard(
                    data: card,
                    onTap: card.onTap ?? () => context.push('/kelas-grup'),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < cards.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromoData {
  const _PromoData({
    required this.kicker,
    required this.title,
    required this.meta,
    required this.action,
    required this.icon,
    this.onTap,
    this.primary = false,
  });

  final String kicker;
  final String title;
  final String meta;
  final String action;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.data, required this.onTap});

  final _PromoData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = data.primary ? Colors.white : scheme.onSurface;
    final muted = data.primary
        ? Colors.white.withValues(alpha: 0.78)
        : scheme.onSurfaceVariant;
    final accent = data.primary ? Colors.white : scheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: data.primary ? AppColors.gradient : null,
            color: data.primary ? null : scheme.surface,
            border: Border.all(
              color: data.primary ? Colors.transparent : scheme.outline,
            ),
            borderRadius: AppRadius.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.kicker.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: data.primary
                          ? Colors.white.withValues(alpha: 0.18)
                          : scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(data.icon, size: 16, color: accent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontSize: 18,
                  height: 1.18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                data.meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: muted),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: data.primary
                      ? Colors.white
                      : scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.action,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: data.primary
                            ? AppColors.primaryDark
                            : scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: data.primary
                          ? AppColors.primaryDark
                          : scheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
