import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Kartu ajakan tryout: aktif bila langganan berjalan.
class TryoutHero extends StatelessWidget {
  const TryoutHero({super.key, required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // Warna: tryout = tantangan belajar → challenge (ungu: ambisi &
        // rasa ingin tahu), beda dari aksi transaksi yang brand.
        // Ujung kedua selalu digelapkan (mode gelap jadi lebih redup). Kontras
        // onChallenge 90% di titik terterang: terang 4.84:1 (#6D4FD8), gelap
        // 4.78:1 (ujung #9484D0); 100%: 5.58:1 / 5.44:1.
        gradient: enabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.challenge,
                  Color.lerp(palette.challenge, Colors.black, 0.15)!,
                ],
              )
            : null,
        color: enabled ? null : theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRYOUT',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: enabled
                  ? palette.onChallenge.withValues(alpha: 0.9)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Uji kesiapanmu',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: enabled ? palette.onChallenge : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '20 soal · 20 menit · dinilai otomatis',
            style: theme.textTheme.bodySmall?.copyWith(
              color: enabled
                  ? palette.onChallenge.withValues(alpha: 0.9)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? onTap : null,
              style: FilledButton.styleFrom(
                backgroundColor: enabled ? palette.onChallenge : null,
                foregroundColor: enabled ? palette.challenge : null,
                minimumSize: const Size(0, 42),
              ),
              child: Text(enabled ? 'Mulai tryout' : 'Langganan untuk membuka'),
            ),
          ),
        ],
      ),
    );
  }
}
