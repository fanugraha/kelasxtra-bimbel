import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../../core/widgets/status_badge.dart';
import 'kelas_grup_providers.dart';
import 'kelas_grup_repository.dart';

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
                eyebrow: 'Kelas grup',
                title: 'Belajar bareng',
                subtitle:
                    'Kuota 3–5 siswa. Program batal otomatis jika kuota minimum tidak terpenuhi.',
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
                            _ClassCard(item: item),
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

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item});

  final GroupClassItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jadwal = (item.firstSession != null && item.lastSession != null)
        ? '${AppFormat.dateShort(item.firstSession!)} – ${AppFormat.dateShort(item.lastSession!)}'
        : '—';
    final full = item.maxSeats == 0 ? 0.0 : item.seatsTaken / item.maxSeats;
    final badge = item.seatsTaken >= item.maxSeats
        ? const StatusBadge(label: 'Penuh', tone: StatusTone.success)
        : item.seatsTaken / item.maxSeats >= 0.7
        ? const StatusBadge(label: 'Hampir penuh', tone: StatusTone.warning)
        : StatusBadge(
            label: item.dibuka ? 'Dibuka' : 'Terkonfirmasi',
            tone: item.dibuka ? StatusTone.info : StatusTone.success,
          );

    return AppCard(
      onTap: () => context.push('/kelas-grup/${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subjectName ?? 'Kelas grup',
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.tutorName ?? 'Tutor'} · ${item.jenjang} · ${item.mode == 'online' ? 'Online' : 'Offline'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Meta(icon: Icons.calendar_today_outlined, label: jadwal),
              _Meta(
                icon: Icons.schedule_rounded,
                label:
                    '${item.totalSesi} pertemuan · ${item.durationMinutes} menit',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: full,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.outline,
                    valueColor: AlwaysStoppedAnimation(
                      full >= 1
                          ? AppColors.success
                          : full < item.minSeats / item.maxSeats
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.seatsTaken} / ${item.maxSeats} kursi',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${AppFormat.rupiah(item.pricePerSession)} / sesi',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12),
                ),
              ),
              OutlinedButton(
                onPressed: () => context.push('/kelas-grup/${item.id}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Lihat detail'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontSize: 10.5),
        ),
      ],
    );
  }
}
