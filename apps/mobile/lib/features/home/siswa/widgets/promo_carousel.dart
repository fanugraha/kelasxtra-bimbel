import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';

/// Karusel kartu promo di home siswa (tryout, paket, kelas grup).
///
/// Warna: kartu tryout = CHALLENGE (ajakan menantang diri, ungu); kartu
/// paket/kelas grup = PROMO (hemat/harga ringan, coral).
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
        role: _PromoRole.challenge,
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
          // Tinggi ikut skala teks agar judul 2 baris + meta 14 tidak terpotong.
          height: 178 * MediaQuery.textScalerOf(context).scale(16) / 16,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
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

enum _PromoRole { challenge, promo }

class _PromoData {
  const _PromoData({
    required this.kicker,
    required this.title,
    required this.meta,
    required this.action,
    required this.icon,
    this.onTap,
    this.role = _PromoRole.promo,
  });

  final String kicker;
  final String title;
  final String meta;
  final String action;
  final IconData icon;
  final VoidCallback? onTap;
  final _PromoRole role;

  /// Kartu tantangan tampil penuh warna (hero); kartu promo bertonal.
  bool get primary => role == _PromoRole.challenge;
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.data, required this.onTap});

  final _PromoData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final (strong, onStrong, soft) = switch (data.role) {
      _PromoRole.challenge => (
        palette.challenge,
        palette.onChallenge,
        palette.challengeSoft,
      ),
      _PromoRole.promo => (palette.promo, palette.onPromo, palette.promoSoft),
    };
    final fg = data.primary ? onStrong : scheme.onSurface;
    final muted = data.primary
        // 0.9: kontras 4.84:1 di ungu challenge (0.78 hanya 4.07:1).
        ? onStrong.withValues(alpha: 0.9)
        : scheme.onSurfaceVariant;
    final accent = data.primary ? onStrong : strong;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Ink(
          decoration: BoxDecoration(
            color: data.primary ? strong : scheme.surface,
            border: Border.all(
              color: data.primary ? Colors.transparent : scheme.outline,
            ),
            borderRadius: AppRadius.card,
            boxShadow: [
              BoxShadow(
                color: (data.primary ? strong : Colors.black).withValues(
                  alpha: data.primary ? 0.20 : 0.045,
                ),
                blurRadius: data.primary ? 24 : 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -34,
                bottom: -50,
                child: Container(
                  width: 142,
                  height: 142,
                  decoration: BoxDecoration(
                    color: data.primary
                        ? onStrong.withValues(alpha: 0.10)
                        : soft,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
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
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: data.primary
                                ? onStrong.withValues(alpha: 0.16)
                                : soft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(data.icon, size: 21, color: accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(color: fg),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      data.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: data.primary ? onStrong : soft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data.action,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: strong,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: strong,
                          ),
                        ],
                      ),
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
