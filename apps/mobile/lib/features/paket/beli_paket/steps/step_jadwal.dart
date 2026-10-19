import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/form_group.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../katalog/katalog_repository.dart';
import '../../paket_repository.dart';
import '../beli_paket_controller.dart';
import '../widgets/jadwal_list.dart';

/// Bagian jadwal: satu pilihan "Hari · jam" per chip. Tanggal mulai otomatis
/// tanggal terdekat yang kosong untuk semua pertemuan paket.
///
/// [busy] null berarti jadwal tutor masih dimuat; daftar kosong berarti tidak
/// ada bentrok (server tetap memvalidasi saat bayar).
class StepJadwal extends StatelessWidget {
  const StepJadwal({
    super.key,
    required this.controller,
    required this.detail,
    required this.busy,
    required this.mine,
  });

  final BeliPaketController controller;
  final TutorDetail detail;
  final List<BusySlot>? busy;
  final List<MySession> mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;

    Widget body;
    if (c.mode == null) {
      body = Text('Pilih mode belajar dulu.', style: theme.textTheme.bodySmall);
    } else if (busy == null) {
      body = Row(
        children: [
          const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Memeriksa jadwal yang masih kosong…',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    } else {
      final options = c.weeklyOptions(
        availability: detail.availability,
        tutorBusy: busy!,
        mine: mine,
      );
      body = options.isEmpty
          ? Text(
              'Jadwal tutor untuk paket ini sudah penuh. Coba jumlah '
              'pertemuan atau durasi lain.',
              style: theme.textTheme.bodySmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChipRow(
                  children: [
                    for (final o in options)
                      Opacity(
                        opacity: o.clash == null ? 1 : 0.4,
                        child: SelectableChip(
                          label:
                              '${AppFormat.longDayName(o.slot.dayOfWeek)} · '
                              '${AppFormat.hhmm(o.startMinutes)}',
                          selected: c.isSelected(o),
                          onTap: o.clash == null
                              ? () => c.selectWeekly(o)
                              : () => ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(content: Text(o.clash!)),
                                  ),
                        ),
                      ),
                  ],
                ),
                if (options.any((o) => o.clash != null)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Jam yang pudar bentrok dengan les kamu yang lain.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldGroup(
          label: 'Jadwal mingguan',
          hint: 'Les seminggu sekali di hari & jam yang sama.',
          child: body,
        ),
        if (c.date != null && c.startMinutes != null) ...[
          const SizedBox(height: AppSpacing.lg),
          JadwalList(dates: c.meetingDates(), startMinutes: c.startMinutes!),
        ],
      ],
    );
  }
}
