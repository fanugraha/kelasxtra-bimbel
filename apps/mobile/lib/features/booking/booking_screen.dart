import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../katalog/katalog_providers.dart';
import '../katalog/katalog_repository.dart';
import 'booking_providers.dart';
import 'snap_screen.dart';

const _durations = [60, 90, 120];

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
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(tutorDetailProvider(widget.tutorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pesan Sesi')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Gagal memuat data tutor',
          message: '$e',
        ),
        data: (d) {
          if (d == null) {
            return const EmptyState(
              icon: Icons.person_off_rounded,
              title: 'Tutor tidak ditemukan',
            );
          }
          return _buildForm(d);
        },
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

        _label('Mapel & Jenjang'),
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
                  }),
                ),
            ],
          ),

        const SizedBox(height: AppSpacing.xl),
        _label('Mode'),
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
                }),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        _label('Durasi'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final d in _durations)
              ChoiceChip(
                label: Text('$d menit'),
                selected: _duration == d,
                onSelected: (_) => setState(() {
                  _duration = d;
                  _startMinutes = null;
                }),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        _label('Jadwal ketersediaan'),
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
          _label('Tanggal'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final d in dates)
                ChoiceChip(
                  label: Text(_formatDate(d)),
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
          _label('Jam mulai'),
          if (times.isEmpty)
            const Text('Durasi tidak muat di slot ini. Pilih durasi lebih pendek.')
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in times)
                  ChoiceChip(
                    label: Text(_hhmm(t)),
                    selected: _startMinutes == t,
                    onSelected: (_) => setState(() => _startMinutes = t),
                  ),
              ],
            ),
        ],

        if (addressRequired) ...[
          const SizedBox(height: AppSpacing.xl),
          _label('Alamat belajar'),
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

        const SizedBox(height: AppSpacing.xl),
        _PriceCard(
          subject: _subject,
          mode: _mode,
          duration: _duration,
        ),

        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],

        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Lanjut ke pembayaran',
          icon: Icons.lock_outline_rounded,
          loading: _submitting,
          onPressed: complete ? () => _submit(detail) : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Slot ditahan 30 menit saat kamu lanjut ke pembayaran.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

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
      final result = await ref.read(bookingRepositoryProvider).createSnap(
            tutorId: widget.tutorId,
            subjectId: _subject!.subjectId,
            jenjang: _subject!.jenjang,
            durationMinutes: _duration,
            mode: _mode!,
            scheduledAt: scheduledAt,
            address: _mode == 'offline' ? _address.text.trim() : null,
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

  List<String> _availableModes(List<TutorAvailabilityItem> availability) {
    final modes = <String>{for (final a in availability) a.mode};
    return ['online', 'offline'].where(modes.contains).toList();
  }

  List<TutorAvailabilityItem> _slotOptions(List<TutorAvailabilityItem> a) {
    if (_mode == null) return const [];
    return a.where((x) => x.mode == _mode).toList();
  }

  List<DateTime> _nextDates(int dayOfWeek, int count) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dartWeekday = dayOfWeek == 0 ? 7 : dayOfWeek;
    var d = today.add(Duration(days: (dartWeekday - today.weekday + 7) % 7));
    return [for (var i = 0; i < count; i++) d = d.add(Duration(days: i == 0 ? 0 : 7))];
  }

  List<int> _startTimes(TutorAvailabilityItem slot, int duration) {
    final start = _toMinutes(slot.startTime);
    final end = _toMinutes(slot.endTime);
    final out = <int>[];
    final isToday = _date != null && _isSameDay(_date!, DateTime.now());
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    for (var m = start; m + duration <= end; m += 60) {
      if (!isToday || m > nowMinutes) out.add(m);
    }
    return out;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _toMinutes(String t) {
    final parts = t.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static const _dayShort = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static String _formatDate(DateTime d) =>
      '${_dayShort[d.weekday % 7]}, ${d.day} ${_monthShort[d.month - 1]}';
}

class _PriceCard extends ConsumerWidget {
  const _PriceCard({required this.subject, required this.mode, required this.duration});

  final TutorSubjectItem? subject;
  final String? mode;
  final int duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (subject == null || mode == null) {
      return AppCard(
        child: Text('Pilih mapel dan mode untuk melihat harga.',
            style: theme.textTheme.bodySmall),
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
        data: (value) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total bayar', style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value == null ? 'Harga belum diset' : _rupiah(value),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: value == null ? null : AppColors.primary),
                  ),
                ],
              ),
            ),
            Text('$duration menit', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  static String _rupiah(int v) {
    final s = v.toString();
    final buf = StringBuffer('Rp');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
