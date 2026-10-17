import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_flavor.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';

/// Layar aksi sesi: absensi, reschedule, batal, ulasan, komplain, dan chat.
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  final _message = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      _toast(success);
      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(myBookingsProvider);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(bookingDetailProvider(widget.bookingId));
    final isTutor = ref.watch(appFlavorProvider) == AppFlavor.tutor;
    final uid = supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Sesi')),
      body: AsyncView<BookingDetail>(
        value: detail,
        errorTitle: 'Gagal memuat sesi',
        onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        builder: (b) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _Summary(booking: b),
            const SizedBox(height: AppSpacing.lg),
            ..._actions(b, isTutor),
            const SizedBox(height: AppSpacing.lg),
            _ChatSection(
              bookingId: widget.bookingId,
              currentUserId: uid,
              isTutor: isTutor,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BookingDetail b, bool isTutor) {
    final widgets = <Widget>[];
    final canChat = b.status != 'pending_payment' && b.status != 'expired';

    if (isTutor) {
      if (b.status == 'confirmed') {
        widgets.add(AppButton(
          label: b.mode == 'offline' ? 'Mulai sesi (cek lokasi)' : 'Mulai sesi',
          icon: Icons.play_circle_rounded,
          loading: _busy,
          onPressed: () => _checkin(b),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
        widgets.add(AppButton(
          label: 'Ajukan reschedule',
          variant: AppButtonVariant.secondary,
          icon: Icons.schedule_rounded,
          loading: false,
          onPressed: () => _rescheduleDialog(b),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
      }
      if (b.status == 'in_progress') {
        widgets.add(AppButton(
          label: 'Catatan sesi',
          icon: Icons.edit_note_rounded,
          variant: AppButtonVariant.secondary,
          loading: false,
          onPressed: () => _noteDialog(b),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
        widgets.add(AppButton(
          label: 'Selesaikan sesi',
          icon: Icons.task_alt_rounded,
          loading: _busy,
          onPressed: () => _run(
            () => ref.read(bookingRepositoryProvider).complete(b.id),
            'Sesi ditandai selesai.',
          ),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
      }
      if (b.status == 'confirmed' || b.status == 'in_progress') {
        widgets.add(AppButton(
          label: 'Tandai siswa tidak hadir',
          variant: AppButtonVariant.ghost,
          loading: _busy,
          onPressed: () => _run(
            () => ref
                .read(bookingRepositoryProvider)
                .markNoShow(b.id, 'student'),
            'Siswa ditandai tidak hadir.',
          ),
        ));
      }
    } else {
      if (b.status == 'in_progress' && b.studentAttendedAt == null) {
        widgets.add(AppButton(
          label: 'Saya hadir',
          icon: Icons.how_to_reg_rounded,
          loading: _busy,
          onPressed: () => _run(
            () => ref.read(bookingRepositoryProvider).studentAttend(b.id),
            'Kehadiranmu tercatat.',
          ),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
      }
      if (b.status == 'confirmed') {
        widgets.add(AppButton(
          label: 'Ajukan reschedule',
          variant: AppButtonVariant.secondary,
          icon: Icons.schedule_rounded,
          loading: false,
          onPressed: () => _rescheduleDialog(b),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
        widgets.add(AppButton(
          label: 'Batalkan sesi',
          variant: AppButtonVariant.ghost,
          loading: _busy,
          onPressed: () => _cancelDialog(b),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
      }
      if (b.status == 'confirmed' &&
          DateTime.now().isAfter(
            b.scheduledAt.add(const Duration(minutes: 15)),
          )) {
        widgets.add(AppButton(
          label: 'Tutor tidak hadir',
          variant: AppButtonVariant.ghost,
          loading: _busy,
          onPressed: () => _run(
            () => ref
                .read(bookingRepositoryProvider)
                .markNoShow(b.id, 'tutor'),
            'Tutor ditandai tidak hadir.',
          ),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
      }
      if (b.status == 'completed') {
        widgets.add(AppButton(
          label: 'Beri ulasan',
          icon: Icons.star_rounded,
          loading: false,
          onPressed: () => _reviewDialog(b),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
      }
      if (b.status == 'completed' || b.status == 'disputed') {
        widgets.add(AppButton(
          label: 'Ajukan komplain',
          variant: AppButtonVariant.secondary,
          loading: false,
          onPressed: () => _complaintDialog(b),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
      }
    }

    if (canChat && widgets.isEmpty) {
      widgets.add(const SizedBox.shrink());
    }
    return widgets;
  }

  Future<void> _checkin(BookingDetail b) async {
    double? lat;
    double? lng;
    if (b.mode == 'offline') {
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          _toast('Izin lokasi dibutuhkan untuk sesi offline.');
          return;
        }
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (e) {
        _toast('Gagal membaca lokasi: $e');
        return;
      }
    }
    await _run(
      () => ref.read(bookingRepositoryProvider).checkin(b.id, lat: lat, lng: lng),
      'Sesi dimulai.',
    );
  }

  Future<void> _rescheduleDialog(BookingDetail b) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 14)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(b.scheduledAt),
    );
    if (time == null) return;
    final reason = await _textDialog('Alasan reschedule', 'Contoh: ada acara keluarga');
    if (reason == null) return;
    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _run(
      () => ref.read(bookingRepositoryProvider).reschedule(b.id, at, reason),
      'Jadwal baru diajukan.',
    );
  }

  Future<void> _cancelDialog(BookingDetail b) async {
    final reason = await _textDialog('Batalkan sesi', 'Alasan pembatalan');
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(bookingRepositoryProvider).cancel(b.id, reason);
      final refund = (res['refund_amount'] as num?)?.toInt() ?? 0;
      _toast('Dibatalkan. Refund dicatat: ${AppFormat.rupiah(refund)}');
      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(myBookingsProvider);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _noteDialog(BookingDetail b) async {
    final material = TextEditingController();
    final progress = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Catatan sesi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: material,
              decoration: const InputDecoration(labelText: 'Materi'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: progress,
              decoration: const InputDecoration(labelText: 'Progres siswa'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref
          .read(bookingRepositoryProvider)
          .saveNote(b.id, material.text.trim(), progress.text.trim()),
      'Catatan tersimpan.',
    );
  }

  Future<void> _reviewDialog(BookingDetail b) async {
    var rating = 5;
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Beri ulasan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setLocal(() => rating = i),
                      icon: Icon(
                        i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Komentar (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kirim')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref
          .read(bookingRepositoryProvider)
          .review(b.id, rating, comment.text.trim()),
      'Ulasan terkirim.',
    );
  }

  Future<void> _complaintDialog(BookingDetail b) async {
    var category = 'quality';
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Ajukan komplain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: const [
                  DropdownMenuItem(value: 'quality', child: Text('Kualitas sesi')),
                  DropdownMenuItem(value: 'schedule', child: Text('Jadwal')),
                  DropdownMenuItem(value: 'tutor_absent', child: Text('Tutor tidak hadir')),
                  DropdownMenuItem(value: 'student_absent', child: Text('Siswa tidak hadir')),
                  DropdownMenuItem(value: 'payment', child: Text('Pembayaran')),
                  DropdownMenuItem(value: 'other', child: Text('Lainnya')),
                ],
                onChanged: (v) => setLocal(() => category = v ?? 'quality'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Ceritakan masalahnya'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kirim')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref
          .read(bookingRepositoryProvider)
          .complain(b.id, category, body.text.trim()),
      'Komplain dikirim. Admin akan meninjau.',
    );
  }

  Future<String?> _textDialog(String title, String hint) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kirim')),
        ],
      ),
    );
    return ok == true ? ctrl.text.trim() : null;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.booking});

  final BookingDetail booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(booking.tutorName, style: theme.textTheme.titleMedium),
              ),
              Text(booking.statusLabel, style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${booking.subjectName} · ${booking.jenjang} · '
            '${booking.durationMinutes} menit · ${booking.mode}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(AppFormat.dateTimeShort(booking.scheduledAt),
              style: theme.textTheme.bodySmall),
          if (booking.address != null && booking.address!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(booking.address!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(AppFormat.rupiah(booking.price), style: theme.textTheme.titleSmall),
          if (booking.refundAmount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Refund dicatat: ${AppFormat.rupiah(booking.refundAmount)}',
                style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _ChatSection extends ConsumerStatefulWidget {
  const _ChatSection({
    required this.bookingId,
    required this.currentUserId,
    required this.isTutor,
  });

  final String bookingId;
  final String? currentUserId;
  final bool isTutor;

  @override
  ConsumerState<_ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends ConsumerState<_ChatSection> {
  final _input = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(bookingMessagesProvider(widget.bookingId));
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Pesan', style: theme.textTheme.titleMedium),
              ),
              IconButton(
                onPressed: () =>
                    ref.invalidate(bookingMessagesProvider(widget.bookingId)),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Muat ulang',
              ),
            ],
          ),
          AsyncView<List<ChatMessage>>(
            value: messages,
            errorTitle: 'Gagal memuat pesan',
            onRetry: () =>
                ref.invalidate(bookingMessagesProvider(widget.bookingId)),
            builder: (list) => Column(
              children: [
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('Belum ada pesan.', style: theme.textTheme.bodySmall),
                  ),
                for (final m in list)
                  Align(
                    alignment: m.senderId == widget.currentUserId
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.senderId == widget.currentUserId
                                ? 'Saya'
                                : (widget.isTutor ? 'Siswa' : 'Tutor'),
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(m.body, style: theme.textTheme.bodyMedium),
                          if (m.flagged)
                            Text(
                              'Nomor telepon disamarkan',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.error),
                            ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        decoration: const InputDecoration(hintText: 'Tulis pesan'),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(bookingRepositoryProvider).sendMessage(widget.bookingId, body);
      _input.clear();
      ref.invalidate(bookingMessagesProvider(widget.bookingId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
