import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';

/// Catatan keamanan di atas daftar pesan: larangan berbagi kontak/bayar luar.
class ChatSafetyNote extends StatelessWidget {
  const ChatSafetyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    // Warna: catatan keamanan = informasi netral → info.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.infoSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 17, color: palette.info),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Demi keamanan, pesan berisi nomor HP, email, tautan, atau ajakan bayar di luar aplikasi akan ditolak.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
