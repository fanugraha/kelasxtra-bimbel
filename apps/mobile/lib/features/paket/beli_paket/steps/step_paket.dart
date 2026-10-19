import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/form_group.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../katalog/katalog_repository.dart';
import '../../paket_providers.dart';
import '../beli_paket_controller.dart';
import '../widgets/price_card.dart';

/// Langkah 1: mapel, mode, durasi, jumlah pertemuan.
class StepPaket extends StatelessWidget {
  const StepPaket({super.key, required this.controller, required this.detail});

  final BeliPaketController controller;
  final TutorDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final subjects = detail.subjects;
    final modes = c.availableModes(detail.availability);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldGroup(
          label: 'Mata pelajaran',
          hint: subjects.isEmpty ? null : 'Pilih satu mapel.',
          child: subjects.isEmpty
              ? Text(
                  'Tutor belum mengatur mapel.',
                  style: theme.textTheme.bodySmall,
                )
              : ChipRow(
                  children: [
                    for (final s in subjects)
                      SelectableChip(
                        label: '${s.subjectName} · ${s.jenjang}',
                        selected: c.subject == s,
                        onTap: () => c.selectSubject(s),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FieldGroup(
          label: 'Mode belajar',
          child: modes.isEmpty
              ? Text(
                  'Tutor belum menetapkan jadwal.',
                  style: theme.textTheme.bodySmall,
                )
              : ChipRow(
                  children: [
                    for (final m in modes)
                      SelectableChip(
                        label: m == 'online' ? 'Online' : 'Offline',
                        selected: c.mode == m,
                        onTap: () => c.selectMode(m),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FieldGroup(
          label: 'Durasi per pertemuan',
          child: ChipRow(
            children: [
              for (final d in AppConstants.durations)
                SelectableChip(
                  label: '$d menit',
                  selected: c.duration == d,
                  onTap: () => c.selectDuration(d),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FieldGroup(
          label: 'Jumlah pertemuan',
          hint: 'Seminggu sekali. Masa berlaku mengikuti jumlah pertemuan.',
          child: ChipRow(
            children: [
              for (final size in paketSizeOptions)
                SelectableChip(
                  label: paketSizeLabel(size),
                  selected: c.size == size,
                  onTap: () => c.selectSize(size),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PriceCard(
          subject: c.subject,
          mode: c.mode,
          duration: c.duration,
          size: c.size,
        ),
      ],
    );
  }
}
