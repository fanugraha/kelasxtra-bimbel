import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../bank_soal_repository.dart';

/// Lembar saat siswa mengetuk topik terkunci: jelaskan kenapa terkunci dan
/// beri dua jalan keluar — coba paket gratis (bila ada) atau langganan.
/// Tidak pernah ada tombol "mati" tanpa penjelasan.
Future<void> showLockedSheet(
  BuildContext context, {
  required CatalogTopic topic,
  required QuestionPack? freePack,
  required int? price,
  required VoidCallback onFree,
  required VoidCallback onSubscribe,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final palette = ctx.palette;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 28,
                  color: palette.brand,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${topic.topicName} untuk pelanggan',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ada ${topic.questionCount} soal ${topic.subjectName} '
                '${topic.jenjang} lengkap dengan pembahasan di topik ini. '
                'Berlangganan untuk membuka semua topik dan tryout.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onSubscribe();
                },
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: Text(
                  price == null
                      ? 'Langganan sekarang'
                      : 'Langganan · ${AppFormat.rupiah(price)}',
                ),
              ),
              if (freePack != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onFree();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: palette.challenge,
                  ),
                  icon: const Icon(Icons.card_giftcard_rounded, size: 19),
                  label: Text(
                    'Coba gratis: ${freePack.topicName ?? freePack.title} '
                    '(${freePack.questionCount} soal)',
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
