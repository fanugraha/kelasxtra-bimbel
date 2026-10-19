import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/form_group.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../katalog/katalog_repository.dart';
import '../../paket_repository.dart';
import '../beli_paket_controller.dart';
import '../widgets/jadwal_list.dart';

/// Langkah 2: hari & jam tutor, tanggal pertemuan pertama, jam mulai.
///
/// [busy] null berarti slot sibuk masih dimuat; daftar kosong berarti tidak
/// ada bentrok (server tetap memvalidasi saat submit).
class StepJadwal extends StatelessWidget {
  const StepJadwal({
    super.key,
    required this.controller,
    required this.detail,
    required this.busy,
  });

  final BeliPaketController controller;
  final TutorDetail detail;
  final List<BusySlot>? busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final slots = c.slotOptions(detail.availability);
    final checked = busy != null;
    final dates = (c.slot == null || busy == null)
        ? const <DateTime>[]
        : c
              .nextDates(c.slot!.dayOfWeek)
              .where((d) => c.dateHasSlot(d, c.slot!, busy!))
              .toList();
    final times = (c.slot == null || c.date == null || busy == null)
        ? const <int>[]
        : c.startTimes(date: c.date!, slot: c.slot!, busy: busy!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldGroup(
          label: 'Hari & jam tutor',
          hint: c.mode == null
              ? null
              : 'Pertemuan berulang tiap minggu di jam ini.',
          child: c.mode == null
              ? const Text('Pilih mode belajar dulu di langkah sebelumnya.')
              : slots.isEmpty
              ? const Text('Tutor belum punya jadwal untuk mode ini.')
              : ChipRow(
                  children: [
                    for (final s in slots)
                      SelectableChip(
                        label: '${s.dayName} ${s.timeRange}',
                        selected: c.slot == s,
                        onTap: () => c.selectSlot(s),
                      ),
                  ],
                ),
        ),
        if (c.slot != null && !checked) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Memeriksa jadwal yang terisi…',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
        if (c.slot != null && checked) ...[
          const SizedBox(height: AppSpacing.xl),
          FieldGroup(
            label: 'Pertemuan pertama',
            hint: dates.length == 1
                ? 'Hanya satu tanggal yang masih kosong untuk paket ini.'
                : 'Empat tanggal terdekat yang masih kosong.',
            child: dates.isEmpty
                ? Text(
                    'Tidak ada tanggal kosong untuk paket ini. Coba jumlah '
                    'pertemuan atau jam lain.',
                    style: theme.textTheme.bodySmall,
                  )
                : ChipRow(
                    children: [
                      for (final d in dates)
                        SelectableChip(
                          label: AppFormat.dateShort(d),
                          selected: c.date == d,
                          onTap: () => c.selectDate(d),
                        ),
                    ],
                  ),
          ),
        ],
        if (c.date != null) ...[
          const SizedBox(height: AppSpacing.xl),
          FieldGroup(
            label: 'Jam mulai',
            child: times.isEmpty
                ? Text(
                    'Semua jam di tanggal ini bentrok dengan sesi lain atau '
                    'tidak muat durasinya. Pilih tanggal lain.',
                    style: theme.textTheme.bodySmall,
                  )
                : ChipRow(
                    children: [
                      for (final t in times)
                        SelectableChip(
                          label: AppFormat.hhmm(t),
                          selected: c.startMinutes == t,
                          onTap: () => c.selectStartMinutes(t),
                        ),
                    ],
                  ),
          ),
        ],
        if (c.date != null && c.startMinutes != null) ...[
          const SizedBox(height: AppSpacing.xl),
          JadwalList(dates: c.meetingDates(), startMinutes: c.startMinutes!),
        ],
      ],
    );
  }
}
