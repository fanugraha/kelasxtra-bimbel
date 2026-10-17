import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import 'absensi_grup_providers.dart';
import 'absensi_grup_repository.dart';

/// Tutor mencentang kehadiran tiap siswa per pertemuan kelas grup.
class AbsensiGrupScreen extends ConsumerWidget {
  const AbsensiGrupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(groupAttendanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Absensi Kelas Grup')),
      body: AsyncView<List<GroupAttendanceRow>>(
        value: rows,
        errorTitle: 'Gagal memuat absensi',
        onRetry: () => ref.invalidate(groupAttendanceProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_rounded,
              title: 'Belum ada kelas grup',
              message: 'Kelas grup yang kamu ampu akan muncul di sini.',
            );
          }
          final sessions = <String, List<GroupAttendanceRow>>{};
          for (final r in list) {
            sessions.putIfAbsent(r.sessionId, () => []).add(r);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(groupAttendanceProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (c, i) {
                final group = sessions.values.elementAt(i);
                return _SessionCard(rows: group);
              },
            ),
          );
        },
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = widget.rows.first;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${first.subjectName} · ${first.jenjang} · ${first.mode}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pertemuan ${first.seq} · ${AppFormat.dateTimeShort(first.scheduledAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: AppSpacing.xl),
          for (final r in widget.rows) ...[
            Text(r.studentName, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            _StatusPicker(
              value: r.status,
              onChanged: (v) => _mark(r, v),
            ),
            if (r != widget.rows.last) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: const [
        ButtonSegment(value: 'hadir', label: Text('Hadir')),
        ButtonSegment(value: 'izin', label: Text('Izin')),
        ButtonSegment(value: 'tidak_hadir', label: Text('Alpa')),
      ],
      selected: value == null ? const <String>{} : {value!},
      emptySelectionAllowed: true,
      onSelectionChanged: (s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
    );
  }
}
