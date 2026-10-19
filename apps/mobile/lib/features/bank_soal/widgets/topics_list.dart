import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_view.dart';
import '../bank_soal_providers.dart';

/// Daftar topik latihan; terkunci bila langganan tidak aktif.
class TopicList extends ConsumerWidget {
  const TopicList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider);
    final sub = ref.watch(mySubscriptionProvider).asData?.value;
    final bisa = sub?.bisaLatihan ?? false;

    return AsyncView<List<Map<String, dynamic>>>(
      value: topics,
      errorTitle: 'Gagal memuat topik',
      onRetry: () => ref.invalidate(topicsProvider),
      builder: (list) => Column(
        children: [
          for (final t in list)
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              onTap: bisa
                  ? () => context.push(
                        '/latihan/${t['id']}',
                        extra: {
                          'name': t['name'],
                          'jenjang': t['jenjang'],
                        },
                      )
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((t['name'] ?? '-') as String,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          '${((t['subjects'] as Map?)?['name'] ?? '-')} · ${t['jenjang'] ?? '-'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    bisa
                        ? Icons.play_circle_outline_rounded
                        : Icons.lock_outline_rounded,
                    color: bisa ? AppColors.primary : Colors.grey,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
