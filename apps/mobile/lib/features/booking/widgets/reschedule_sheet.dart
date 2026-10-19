import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../katalog/katalog_providers.dart';
import '../../paket/paket_providers.dart';
import '../booking_repository.dart';
import '../reschedule_slots.dart';

/// Pilih tanggal & jam baru dari ketersediaan tutor. Mengembalikan DateTime
/// lokal, atau null bila ditutup.
class RescheduleSheet extends ConsumerStatefulWidget {
  const RescheduleSheet({super.key, required this.booking});

  final BookingDetail booking;

  @override
  ConsumerState<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<RescheduleSheet> {
  DateTime? _date;
  int? _startMinutes;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final detail = ref.watch(tutorDetailProvider(b.tutorId));
    final busy = ref.watch(tutorBusyProvider(b.tutorId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SafeArea(
        child: detail.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _Message(
            text: 'Gagal memuat jadwal tutor. Coba lagi nanti.',
            title: 'Pilih jadwal baru',
          ),
          data: (d) {
            if (d == null) {
              return const _Message(
                text: 'Data tutor tidak ditemukan.',
                title: 'Pilih jadwal baru',
              );
            }
            final dates = rescheduleDates(
              availability: d.availability,
              mode: b.mode,
            );
            if (dates.isEmpty) {
              return _Message(
                title: 'Pilih jadwal baru',
                text:
                    'Tutor belum punya jadwal ${b.mode == 'online' ? 'online' : 'offline'} '
                    'dalam 14 hari ke depan.',
              );
            }
            final date = dates.contains(_date) ? _date! : dates.first;
            final busySlots = switch (busy) {
              AsyncData(:final value) => value,
              _ => null,
            };
            final minutes = busySlots == null
                ? null
                : rescheduleMinutes(
                    availability: d.availability,
                    date: date,
                    mode: b.mode,
                    durationMinutes: b.durationMinutes,
                    busy: busySlots,
                    oldStart: b.scheduledAt,
                  );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Pilih jadwal baru', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sesi sekarang ${AppFormat.dateTimeShort(b.scheduledAt)} WIB · '
                    '${b.durationMinutes} menit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Tanggal', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: dates.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final day = dates[i];
                        return SelectableChip(
                          label: AppFormat.dateShort(day),
                          selected: day == date,
                          onTap: () => setState(() {
                            _date = day;
                            _startMinutes = null;
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Jam mulai (WIB)', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  if (minutes == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (minutes.isEmpty)
                    Text(
                      'Tidak ada jam kosong pada tanggal ini. Pilih tanggal lain.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final m in minutes)
                          SelectableChip(
                            label: AppFormat.hhmm(m),
                            selected: _startMinutes == m,
                            onTap: () => setState(() => _startMinutes = m),
                          ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Lanjut',
                    onPressed:
                        minutes == null ||
                            _startMinutes == null ||
                            !minutes.contains(_startMinutes)
                        ? null
                        : () => Navigator.of(context).pop(
                            DateTime(
                              date.year,
                              date.month,
                              date.day,
                              0,
                              _startMinutes!,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Text(text, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Tutup',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
