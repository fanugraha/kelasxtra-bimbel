import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';

import '../../core/format.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../../core/widgets/status_badge.dart';
import 'absensi_grup_providers.dart';
import 'absensi_grup_repository.dart';

/// Tutor mencentang kehadiran tiap siswa per pertemuan kelas grup.
class AbsensiGrupScreen extends ConsumerWidget {
  const AbsensiGrupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(groupAttendanceProvider);

    return Scaffold(
      body: SafeArea(
        child: AsyncView<List<GroupAttendanceRow>>(
          value: rows,
          errorTitle: 'Gagal memuat absensi',
          onRetry: () => ref.invalidate(groupAttendanceProvider),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(
                padding: screenPadding,
                children: const [
                  ScreenHead(
                    eyebrow: 'Kelas grup',
                    title: 'Absensi',
                    subtitle: 'Kehadiran siswa per pertemuan.',
                  ),
                  SizedBox(height: 40),
                  EmptyState(
                    icon: Icons.groups_rounded,
                    title: 'Belum ada kelas grup',
                    message: 'Kelas grup yang kamu ampu akan muncul di sini.',
                  ),
                ],
              );
            }
            final sessions = <String, List<GroupAttendanceRow>>{};
            for (final r in list) {
              sessions.putIfAbsent(r.sessionId, () => []).add(r);
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(groupAttendanceProvider),
              child: ListView(
                padding: screenPadding,
                children: [
                  ScreenHead(
                    eyebrow: 'Kelas grup',
                    title: 'Absensi',
                    subtitle:
                        '${sessions.length} pertemuan menunggu · tersimpan otomatis.',
                  ),
                  const SizedBox(height: 18),
                  for (final group in sessions.values) ...[
                    _SessionCard(rows: group),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionCard extends ConsumerStatefulWidget {
  const _SessionCard({required this.rows});

  final List<GroupAttendanceRow> rows;

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  var _busy = false;

  Future<void> _mark(GroupAttendanceRow r, String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(groupAttendanceRepositoryProvider)
          .mark(r.sessionId, r.studentId, status);
      ref.invalidate(groupAttendanceProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = widget.rows.first;
    final pending = widget.rows.where((r) => r.status == null).length;

    return AppCard(
      padding: const EdgeInsets.all(15),
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
                      'Pertemuan ${first.seq}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${first.subjectName} · ${AppFormat.dateTimeShort(first.scheduledAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: pending == 0 ? 'Tersimpan' : '$pending belum diisi',
                tone: pending == 0 ? StatusTone.success : StatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final r in widget.rows)
            _StudentRow(
              row: r,
              busy: _busy,
              onMark: (status) => _mark(r, status),
            ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                minHeight: 3,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.row,
    required this.busy,
    required this.onMark,
  });

  final GroupAttendanceRow row;
  final bool busy;
  final ValueChanged<String> onMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = row.studentName;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: context.palette.brandSoft,
            child: Text(
              initial,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 1),
                Text(
                  '${row.jenjang} · ${row.mode}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _AttendButton(
            label: 'Hadir',
            selected: row.status == 'hadir',
            // Warna: hadir = success, alpa = danger (status nyata).
            color: context.palette.success,
            soft: context.palette.successSoft,
            onTap: busy ? null : () => onMark('hadir'),
          ),
          const SizedBox(width: 4),
          _AttendButton(
            label: 'Alpa',
            selected: row.status == 'tidak_hadir',
            color: context.palette.danger,
            soft: context.palette.dangerSoft,
            onTap: busy ? null : () => onMark('tidak_hadir'),
          ),
        ],
      ),
    );
  }
}

class _AttendButton extends StatelessWidget {
  const _AttendButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.soft,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final Color soft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? soft : Colors.transparent,
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected
                ? color
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
