import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/format.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/person_photo.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../katalog/katalog_repository.dart';
import '../../paket_providers.dart';
import '../../paket_repository.dart';
import '../beli_paket_controller.dart';
import '../widgets/checkout_parts.dart';

/// Langkah 1 — Atur kelas: mapel, metode, durasi, jumlah pertemuan, jadwal
/// mingguan (+ alamat bila offline). Tiap isian satu kartu bernomor yang
/// berubah jadi centang saat terisi, jadi siswa tahu sisa isiannya.
class StepAturKelas extends ConsumerWidget {
  const StepAturKelas({
    super.key,
    required this.controller,
    required this.detail,
    required this.busy,
    required this.mine,
  });

  final BeliPaketController controller;
  final TutorDetail detail;

  /// null = jadwal tutor masih dimuat.
  final List<BusySlot>? busy;
  final List<MySession> mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = controller;
    final offline = c.mode == 'offline';
    const gap = SizedBox(height: AppSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _subjects(context),
        gap,
        _modes(context),
        gap,
        _durations(context),
        gap,
        _sizes(context, ref),
        gap,
        _schedule(context),
        if (offline) ...[gap, _address(context)],
      ],
    );
  }

  Widget _subjects(BuildContext context) {
    final c = controller;
    final subjects = detail.subjects;
    return CheckoutSection(
      number: 1,
      title: 'Mata pelajaran',
      done: c.subject != null,
      child: subjects.isEmpty
          ? const _Muted('Tutor belum mengatur mapel.')
          : Column(
              children: [
                for (final s in subjects) ...[
                  OptionCard(
                    icon: subjectIconFor(s.subjectName),
                    title: s.subjectName,
                    subtitle: 'Jenjang ${s.jenjang}',
                    selected: c.subject == s,
                    onTap: () => c.selectSubject(s),
                  ),
                  if (s != subjects.last) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
    );
  }

  Widget _modes(BuildContext context) {
    final c = controller;
    final modes = c.availableModes(detail.availability);
    return CheckoutSection(
      number: 2,
      title: 'Metode belajar',
      done: c.mode != null,
      child: modes.isEmpty
          ? const _Muted('Tutor belum menetapkan jadwal.')
          : Column(
              children: [
                for (final m in modes) ...[
                  OptionCard(
                    icon: m == 'online'
                        ? Icons.videocam_rounded
                        : Icons.home_rounded,
                    title: m == 'online' ? 'Online' : 'Tatap muka',
                    subtitle: m == 'online'
                        ? 'Belajar lewat Zoom dari rumah'
                        : 'Tutor datang ke alamatmu',
                    selected: c.mode == m,
                    onTap: () => c.selectMode(m),
                  ),
                  if (m != modes.last) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
    );
  }

  Widget _durations(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final c = controller;
    return CheckoutSection(
      number: 3,
      title: 'Durasi per pertemuan',
      done: true,
      child: Row(
        children: [
          for (final d in AppConstants.durations) ...[
            Expanded(
              child: Material(
                color: c.duration == d ? palette.brand : scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(
                    color: c.duration == d ? palette.brand : scheme.outline,
                  ),
                ),
                child: InkWell(
                  onTap: () => c.selectDuration(d),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Text(
                          '$d',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c.duration == d
                                ? palette.onBrand
                                : scheme.onSurface,
                          ),
                        ),
                        Text(
                          'menit',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: c.duration == d
                                ? palette.onBrand.withValues(alpha: 0.85)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (d != AppConstants.durations.last)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  /// Jumlah pertemuan + harga tiap pilihan (begitu mapel & metode terpilih),
  /// supaya siswa bisa membandingkan tanpa bolak-balik.
  Widget _sizes(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = controller;
    final canPrice = c.subject != null && c.mode != null;
    final prices = <int, int?>{
      for (final s in paketSizeOptions)
        s: canPrice
            ? ref
                  .watch(
                    packagePriceProvider((
                      jenjang: c.subject!.jenjang,
                      duration: c.duration,
                      mode: c.mode!,
                      totalSesi: s,
                    )),
                  )
                  .value
            : null,
    };
    // Lencana "Hemat" untuk harga per pertemuan termurah (bila berbeda).
    final perSesi = {
      for (final e in prices.entries)
        if (e.value != null) e.key: e.value! ~/ e.key,
    };
    int? cheapest;
    if (perSesi.length > 1 && perSesi.values.toSet().length > 1) {
      cheapest = perSesi.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;
    }

    return CheckoutSection(
      number: 4,
      title: 'Jumlah pertemuan',
      hint: 'Seminggu sekali di hari & jam yang sama.',
      done: true,
      child: Column(
        children: [
          for (final s in paketSizeOptions) ...[
            OptionCard(
              title: '$s pertemuan',
              subtitle:
                  'Berlaku ${paketMasaBerlaku(s)}'
                  '${perSesi[s] == null ? '' : ' · ${AppFormat.rupiah(perSesi[s]!)}/sesi'}',
              badge: s == cheapest ? 'Hemat' : null,
              selected: c.size == s,
              onTap: () => c.selectSize(s),
              trailing: prices[s] == null
                  ? null
                  : Text(
                      AppFormat.rupiah(prices[s]!),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            if (s != paketSizeOptions.last)
              const SizedBox(height: AppSpacing.sm),
          ],
          if (!canPrice) ...[
            const SizedBox(height: AppSpacing.sm),
            const _Muted('Harga tampil setelah mapel & metode dipilih.'),
          ],
        ],
      ),
    );
  }

  /// Jadwal mingguan dikelompokkan per hari: "Senin" lalu chip jam-jamnya.
  Widget _schedule(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final c = controller;

    Widget body;
    if (c.mode == null) {
      body = const _Muted('Pilih metode belajar dulu.');
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
              'Memeriksa jam yang masih kosong…',
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
      final byDay = <int, List<WeeklyOption>>{};
      for (final o in options) {
        byDay.putIfAbsent(o.slot.dayOfWeek, () => []).add(o);
      }
      body = options.isEmpty
          ? const _Muted(
              'Jam tutor untuk paket ini sudah penuh. Coba jumlah pertemuan '
              'atau durasi lain.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in byDay.entries) ...[
                  Text(
                    AppFormat.longDayName(e.key),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in e.value)
                        Opacity(
                          opacity: o.clash == null ? 1 : 0.4,
                          child: SelectableChip(
                            label: AppFormat.hhmm(o.startMinutes),
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
                  const SizedBox(height: AppSpacing.md),
                ],
                if (options.any((o) => o.clash != null))
                  const _Muted('Jam yang pudar bentrok dengan les kamu lain.'),
                if (c.date != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: palette.successSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 20,
                          color: palette.success,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Mulai ${AppFormat.dateLong(c.date!)}, '
                            '${c.size}× sampai '
                            '${AppFormat.dateShort(c.meetingDates().last)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
    }

    return CheckoutSection(
      number: 5,
      title: 'Jadwal mingguan',
      hint: 'Pilih hari & jam. Tanggal mulai otomatis yang terdekat.',
      done: c.date != null,
      child: body,
    );
  }

  Widget _address(BuildContext context) {
    final c = controller;
    return CheckoutSection(
      number: 6,
      title: 'Alamat belajar',
      hint: 'Alamat lengkap supaya tutor tidak tersesat.',
      done: c.address.text.trim().isNotEmpty,
      child: TextField(
        controller: c.address,
        minLines: 2,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        onChanged: (_) => c.refresh(),
        decoration: const InputDecoration(
          hintText: 'Contoh: Jl. Melati 12, RT 03/RW 05, Depok',
        ),
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall);
}
