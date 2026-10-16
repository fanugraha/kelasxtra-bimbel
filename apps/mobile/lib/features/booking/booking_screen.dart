import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_text.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../katalog/katalog_providers.dart';
import '../katalog/katalog_repository.dart';
import '../paket/paket_providers.dart';
import '../paket/paket_repository.dart';
import 'booking_providers.dart';
import 'snap_screen.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.tutorId});

  final String tutorId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  TutorSubjectItem? _subject;
  int _duration = 60;
  String? _mode;
  TutorAvailabilityItem? _slot;
  DateTime? _date;
  int? _startMinutes;
  final _address = TextEditingController();
  final _voucher = TextEditingController();
  String? _appliedCode;
  int _discount = 0;
  String? _voucherError;
  bool _useQuota = false;
  var _checkingVoucher = false;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _voucher.dispose();
    super.dispose();
  }

  /// Diskon berlaku untuk kombinasi mapel/mode/durasi tertentu; bila berubah, reset.
  void _resetVoucher() {
    _appliedCode = null;
    _discount = 0;
    _voucherError = null;
    _useQuota = false;
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(tutorDetailProvider(widget.tutorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pesan Sesi')),
      body: AsyncView<TutorDetail?>(
        value: detail,
        errorTitle: 'Gagal memuat data tutor',
        onRetry: () => ref.invalidate(tutorDetailProvider(widget.tutorId)),
        builder: (d) => d == null
            ? const EmptyState(
                icon: Icons.person_off_rounded,
                title: 'Tutor tidak ditemukan',
              )
            : _buildForm(d),
      ),
    );
  }

  Widget _buildForm(TutorDetail detail) {
    final theme = Theme.of(context);
    final subjects = detail.subjects;
    final modes = _availableModes(detail.availability);
    final slots = _slotOptions(detail.availability);
    final dates = _slot == null ? const <DateTime>[] : _nextDates(_slot!.dayOfWeek, 4);
    final times = (_slot == null || _date == null)
        ? const <int>[]
        : _startTimes(_slot!, _duration);
    final addressRequired = _mode == 'offline';
    final packages =
        ref.watch(activePackagesForTutorProvider(widget.tutorId)).asData?.value ??
            const <PackageItem>[];
    PackageItem? matchPackage;
    if (_subject != null && _mode != null) {
      for (final p in packages) {
        if (p.subjectId == _subject!.subjectId &&
            p.jenjang == _subject!.jenjang &&
            p.durationMinutes == _duration &&
            p.mode == _mode &&
            p.sisaSesi > 0) {
          matchPackage = p;
          break;
        }
      }
    }
    final complete = _subject != null &&
        _mode != null &&
        _slot != null &&
        _date != null &&
        _startMinutes != null &&
        (!addressRequired || _address.text.trim().isNotEmpty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Text(detail.tutor.fullName, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xl),

        _SectionLabel('Mapel & Jenjang'),
        if (subjects.isEmpty)
          const Text('Tutor belum mengatur mapel.')
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in subjects)
                ChoiceChip(
                  label: Text('${s.subjectName} · ${s.jenjang}'),
                  selected: _subject == s,
                  onSelected: (_) => setState(() {
                    _subject = s;
                    _resetSchedule();
                    _resetVoucher();
                  }),
                ),
            ],
          ),

        const SizedBox(height: AppSpacing.xl),
        _SectionLabel('Mode'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final m in modes)
              ChoiceChip(
                label: Text(m == 'online' ? 'Online' : 'Offline'),
                selected: _mode == m,
                onSelected: (_) => setState(() {
                  _mode = m;
                  _resetSchedule();
                  _resetVoucher();
                }),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        _SectionLabel('Durasi'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final d in AppConstants.durations)
              ChoiceChip(
                label: Text('$d menit'),
                selected: _duration == d,
                onSelected: (_) => setState(() {
                  _duration = d;
                  _startMinutes = null;
                  _resetVoucher();
                }),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        _SectionLabel('Jadwal ketersediaan'),
        if (slots.isEmpty)
          const Text('Tutor belum punya jadwal untuk mode ini.')
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in slots)
                ChoiceChip(
                  label: Text('${s.dayName} ${s.timeRange}'),
                  selected: _slot == s,
                  onSelected: (_) => setState(() {
                    _slot = s;
                    _date = null;
                    _startMinutes = null;
                  }),
                ),
            ],
          ),

        if (_slot != null && dates.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('Tanggal'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final d in dates)
                ChoiceChip(
                  label: Text(AppFormat.dateShort(d)),
                  selected: _date == d,
                  onSelected: (_) => setState(() {
                    _date = d;
                    _startMinutes = null;
                  }),
                ),
            ],
          ),
        ],

        if (_date != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('Jam mulai'),
          if (times.isEmpty)
            const Text('Durasi tidak muat di slot ini. Pilih durasi lebih pendek.')
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in times)
                  ChoiceChip(
                    label: Text(AppFormat.hhmm(t)),
                    selected: _startMinutes == t,
                    onSelected: (_) => setState(() => _startMinutes = t),
                  ),
              ],
            ),
        ],

        if (addressRequired) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Alamat belajar'),
          TextField(
            controller: _address,
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Alamat lengkap untuk sesi offline',
            ),
          ),
        ],

        if (matchPackage != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Pembayaran'),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: Text('Pakai kuota paket (sisa ${matchPackage.sisaSesi})'),
                selected: _useQuota,
                onSelected: (_) => setState(() => _useQuota = true),
              ),
              ChoiceChip(
                label: const Text('Bayar per sesi'),
                selected: !_useQuota,
                onSelected: (_) => setState(() => _useQuota = false),
              ),
            ],
          ),
        ],

        if (!_useQuota) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Kode voucher (opsional)'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucher,
                  enabled: _appliedCode == null,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Contoh: HEMAT10'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: _appliedCode != null ? 'Batal' : 'Pakai',
                expand: false,
                variant: AppButtonVariant.secondary,
                loading: _checkingVoucher,
                onPressed: (_subject == null || _mode == null)
                    ? null
                    : (_appliedCode != null ? _clearVoucher : _applyVoucher),
              ),
            ],
          ),
          if (_voucherError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _voucherError!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
          if (_appliedCode != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Voucher ${_appliedCode!} dipakai — hemat ${AppFormat.rupiah(_discount)}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.success),
              ),
            ),
        ],

        const SizedBox(height: AppSpacing.xl),
        _PriceCard(
          subject: _subject,
          mode: _mode,
          duration: _duration,
          discount: _discount,
          useQuota: _useQuota,
        ),

        AppErrorText(_error),

        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: _useQuota ? 'Pesan dengan kuota paket' : 'Lanjut ke pembayaran',
          icon: _useQuota
              ? Icons.card_membership_rounded
              : Icons.lock_outline_rounded,
          loading: _submitting,
          onPressed: complete ? () => _submit(detail) : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _useQuota
              ? 'Satu kuota paket akan dipakai. Tak ada pembayaran tambahan.'
              : 'Slot ditahan 30 menit saat kamu lanjut ke pembayaran.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _submit(TutorDetail detail) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final scheduledAt = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _startMinutes! ~/ 60,
        _startMinutes! % 60,
      );
      final address = _mode == 'offline' ? _address.text.trim() : null;

      if (_useQuota) {
        final packages =
            await ref.read(paketRepositoryProvider).fetchActiveForTutor(widget.tutorId);
        PackageItem? match;
        for (final p in packages) {
          if (p.subjectId == _subject!.subjectId &&
              p.jenjang == _subject!.jenjang &&
              p.durationMinutes == _duration &&
              p.mode == _mode &&
              p.sisaSesi > 0) {
            match = p;
            break;
          }
        }
        if (match == null) throw Exception('Paket tidak lagi tersedia');
        await ref.read(paketRepositoryProvider).bookWithPackage(
              packageId: match.id,
              scheduledAt: scheduledAt,
              address: address,
            );
        if (!mounted) return;
        ref.invalidate(myBookingsProvider);
        ref.invalidate(myPackagesProvider);
        ref.invalidate(activePackagesForTutorProvider(widget.tutorId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi dipesan dengan kuota paket.')),
        );
        Navigator.of(context).pop(true);
        return;
      }

      final result = await ref.read(bookingRepositoryProvider).createSnap(
            tutorId: widget.tutorId,
            subjectId: _subject!.subjectId,
            jenjang: _subject!.jenjang,
            durationMinutes: _duration,
            mode: _mode!,
            scheduledAt: scheduledAt,
            address: address,
            voucherCode: _appliedCode,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SnapScreen(redirectUrl: result.redirectUrl),
        ),
      );
      if (!mounted) return;
      ref.invalidate(myBookingsProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetSchedule() {
    _slot = null;
    _date = null;
    _startMinutes = null;
  }

  Future<void> _applyVoucher() async {
    final code = _voucher.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checkingVoucher = true;
      _voucherError = null;
    });
    try {
      final price = await ref.read(priceProvider((
        jenjang: _subject!.jenjang,
        duration: _duration,
        mode: _mode!,
      )).future);
      if (price == null) throw Exception('Harga belum diset');
      final discount = await ref
          .read(bookingRepositoryProvider)
          .checkVoucher(code: code, price: price);
      if (!mounted) return;
      setState(() {
        _appliedCode = code.toUpperCase();
        _discount = discount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appliedCode = null;
        _discount = 0;
        _voucherError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _checkingVoucher = false);
    }
  }

  void _clearVoucher() {
    setState(() {
      _voucher.clear();
      _resetVoucher();
    });
  }

  List<String> _availableModes(List<TutorAvailabilityItem> availability) {
    final modes = <String>{for (final a in availability) a.mode};
    return ['online', 'offline'].where(modes.contains).toList();
  }

  List<TutorAvailabilityItem> _slotOptions(List<TutorAvailabilityItem> a) {
    if (_mode == null) return const [];
    return a.where((x) => x.mode == _mode).toList();
  }

  /// Empat tanggal terdekat untuk hari tertentu (0 = Minggu … 6 = Sabtu).
  List<DateTime> _nextDates(int dayOfWeek, int count) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dartWeekday = dayOfWeek == 0 ? 7 : dayOfWeek;
    final first = today.add(Duration(days: (dartWeekday - today.weekday + 7) % 7));
    return [for (var i = 0; i < count; i++) first.add(Duration(days: i * 7))];
  }

  /// Jam mulai yang muat durasi di dalam slot, dan belum lewat bila hari ini.
  List<int> _startTimes(TutorAvailabilityItem slot, int duration) {
    final start = AppFormat.minutesOfTime(slot.startTime);
    final end = AppFormat.minutesOfTime(slot.endTime);
    final isToday = _date != null && _isSameDay(_date!, DateTime.now());
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    return [
      for (var m = start; m + duration <= end; m += 60)
        if (!isToday || m > nowMinutes) m,
    ];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _PriceCard extends ConsumerWidget {
  const _PriceCard({
    required this.subject,
    required this.mode,
    required this.duration,
    this.discount = 0,
    this.useQuota = false,
  });

  final TutorSubjectItem? subject;
  final String? mode;
  final int duration;
  final int discount;
  final bool useQuota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (subject == null || mode == null) {
      return AppCard(
        child: Text(
          'Pilih mapel dan mode untuk melihat harga.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (useQuota) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_membership_rounded, size: 18, color: AppColors.success),
                const SizedBox(width: AppSpacing.xs),
                Text('Ditanggung kuota paket', style: theme.textTheme.bodySmall),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            Text('Total bayar', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppFormat.rupiah(0),
              style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      );
    }
    final price = ref.watch(priceProvider((
      jenjang: subject!.jenjang,
      duration: duration,
      mode: mode!,
    )));
    return AppCard(
      child: price.when(
        loading: () => const SizedBox(
          height: 24,
          child: Align(alignment: Alignment.centerLeft, child: LinearProgressIndicator()),
        ),
        error: (e, _) => Text('Gagal memuat harga.\n$e', style: theme.textTheme.bodySmall),
        data: (value) {
          final total = value == null ? null : (value - discount).clamp(0, value);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (discount > 0 && value != null) ...[
                Row(
                  children: [
                    Text('Harga normal', style: theme.textTheme.bodySmall),
                    const Spacer(),
                    Text(
                      AppFormat.rupiah(value),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(decoration: TextDecoration.lineThrough),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text('Diskon voucher',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.success)),
                    const Spacer(),
                    Text(
                      '-${AppFormat.rupiah(discount)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.success),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total bayar', style: theme.textTheme.bodySmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          total == null ? 'Harga belum diset' : AppFormat.rupiah(total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: total == null ? null : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text('$duration menit', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
