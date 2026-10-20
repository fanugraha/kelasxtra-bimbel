import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import 'kelas_grup_providers.dart';
import 'kelas_grup_repository.dart';
import 'widgets/group_class_card.dart';

class KelasGrupScreen extends ConsumerWidget {
  const KelasGrupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(groupClassesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupClassesProvider),
          child: ListView(
            padding: screenPadding,
            children: [
              const ScreenHead(
                showBack: true,
                title: 'Belajar bareng',
                subtitle:
                    'Belajar 3–5 siswa dengan satu tutor, jadwal tetap, harga '
                    'lebih ringan. Bila kuota minimum tidak terpenuhi, dana '
                    'kembali penuh.',
              ),
              const SizedBox(height: 18),
              AsyncView<List<GroupClassItem>>(
                value: classes,
                errorTitle: 'Gagal memuat kelas grup',
                onRetry: () => ref.invalidate(groupClassesProvider),
                builder: (list) => list.isEmpty
                    ? const EmptyState(
                        icon: Icons.groups_rounded,
                        title: 'Belum ada kelas grup',
                        message:
                            'Kelas grup akan muncul di sini saat admin membukanya.',
                      )
                    : Column(
                        children: [
                          for (final item in list) ...[
                            GroupClassCard(item: item),
                            const SizedBox(height: 9),
                          ],
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
