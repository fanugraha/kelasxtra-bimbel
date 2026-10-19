import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Kartu ajakan tryout: aktif bila langganan berjalan.
class TryoutHero extends StatelessWidget {
  const TryoutHero({super.key, required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: enabled ? AppColors.gradient : null,
        color: enabled ? null : theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRYOUT',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: enabled
                  ? Colors.white70
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Uji kesiapanmu',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              color: enabled ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '20 soal · 20 menit · dinilai otomatis',
            style: theme.textTheme.bodySmall?.copyWith(
              color: enabled ? Colors.white70 : null,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? onTap : null,
              style: FilledButton.styleFrom(
                backgroundColor: enabled ? Colors.white : null,
                foregroundColor: enabled ? AppColors.primary : null,
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
