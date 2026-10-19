import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors.dart';

import '../../core/app_flavor.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/async_view.dart';
import '../auth/auth_providers.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';
import 'widgets/reschedule_card.dart';
import 'widgets/reschedule_sheet.dart';
import 'widgets/session_note_card.dart';
import 'widgets/class_access_card.dart';
import 'widgets/session_hero.dart';
import 'widgets/session_options.dart';

/// Layar aksi sesi: absensi, reschedule, batal, ulasan, komplain, dan chat.
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  var _busy = false;

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
      ref.invalidate(bookingRescheduleProvider(widget.bookingId));
      ref.invalidate(myBookingsProvider);
      ref.invalidate(tutorBookingsProvider);
      ref.invalidate(myCreditProvider);
    } catch (e) {
      _toast(cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openChat(BookingDetail b, bool isTutor) => context.push(
    '/chat/room/${isTutor ? b.studentId : b.tutorId}',
    extra: {'name': isTutor ? b.studentName : b.tutorName},
  );

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(bookingDetailProvider(widget.bookingId));
    final isTutor = ref.watch(appFlavorProvider) == AppFlavor.tutor;

    return Scaffold(
      body: AsyncView<BookingDetail>(
        value: detail,
        errorTitle: 'Gagal memuat sesi',
        onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        builder: (b) {
          // Fungsi utama layar ini: masuk kelas & membaca catatan tutor.
          // Sebelum/selama sesi → kartu masuk kelas di atas; setelah selesai
          // → catatan yang paling dicari, jadi catatan naik ke atas.
          final done = b.status == 'completed';
          final access = ClassAccessCard(
            booking: b,
            isTutor: isTutor,
            onChat: () => _openChat(b, isTutor),
            onEditLink: isTutor && b.mode == 'online' && !done
                ? () => _linkDialog(b)
                : null,
          );
          final notes = SessionNoteCard(
            note: b.note,
            onEdit: _canEditNote(b, isTutor) ? () => _noteDialog(b) : null,
            emptyHint: isTutor
                ? 'Catatan wajib diisi sebelum sesi bisa ditandai selesai.'
                : done
                ? 'Tutor tidak meninggalkan catatan untuk sesi ini.'
                : 'Catatan dari tutor muncul setelah sesi berjalan.',
          );
          final primary = _primaryActions(b, isTutor);
          final options = _options(b, isTutor);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(bookingDetailProvider(widget.bookingId));
              ref.invalidate(bookingRescheduleProvider(widget.bookingId));
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SessionHero(
                  booking: b,
                  isTutor: isTutor,
                  onChat: () => _openChat(b, isTutor),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxl + 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _rescheduleSection(b),
                      if (done) ...[
                        notes,
                        for (final w in primary) ...[
                          const SizedBox(height: AppSpacing.md),
                          w,
                        ],
                      ] else ...[
                        access,
                        for (final w in primary) ...[
                          const SizedBox(height: AppSpacing.md),
                          w,
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        notes,
                      ],
                      if (options.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        SessionOptions(options: options, busy: _busy),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Aksi utama sesuai tahap sesi — paling banyak satu-dua tombol penuh.
  List<Widget> _primaryActions(BookingDetail b, bool isTutor) {
    final widgets = <Widget>[];
    if (isTutor) {
      if (b.status == 'confirmed') {
        widgets.add(
          AppButton(
            label: b.mode == 'offline'
                ? 'Mulai sesi (cek lokasi)'
                : 'Mulai sesi',
            icon: Icons.play_circle_rounded,
            loading: _busy,
            onPressed: () => _checkin(b),
          ),
        );
      }
      if (b.status == 'no_show_tutor') {
        widgets.add(
          AppButton(
            label: 'Jadwalkan ulang pertemuan',
            icon: Icons.event_repeat_rounded,
            loading: _busy,
            onPressed: () => _rescheduleNoShowDialog(b),
          ),
        );
      }
      if (b.status == 'in_progress') {
        final perluCatatan = b.note == null;
        widgets.add(
          AppButton(
            label: perluCatatan
                ? 'Isi catatan lalu selesaikan'
                : 'Selesaikan sesi',
            icon: perluCatatan
                ? Icons.edit_note_rounded
                : Icons.task_alt_rounded,
            loading: _busy,
            onPressed: perluCatatan
                ? () => _noteDialog(b)
                : () => _run(
                    () => ref.read(bookingRepositoryProvider).complete(b.id),
                    'Sesi ditandai selesai.',
                  ),
          ),
        );
      }
    } else {
      if (b.status == 'in_progress' && b.studentAttendedAt == null) {
        widgets.add(
          AppButton(
            label: 'Saya hadir',
            icon: Icons.how_to_reg_rounded,
            loading: _busy,
            onPressed: () => _run(
              () => ref.read(bookingRepositoryProvider).studentAttend(b.id),
              'Kehadiranmu tercatat.',
            ),
          ),
        );
      }
      if (b.status == 'completed' && !b.hasReview) {
        widgets.add(
          AppButton(
            label: 'Beri ulasan',
            icon: Icons.star_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => _reviewDialog(b),
          ),
        );
      }
    }
    return widgets;
  }

  /// Aksi yang jarang dipakai → daftar "Opsi lain" di bawah.
  List<SessionOption> _options(BookingDetail b, bool isTutor) {
    final options = <SessionOption>[];
    if (b.status == 'confirmed') {
      options.add(
        SessionOption(
          icon: Icons.schedule_rounded,
          label: 'Ajukan ganti hari',
          subtitle: isTutor
              ? 'Siswa perlu menyetujui jadwal barunya'
              : 'Tutor perlu menyetujui jadwal barunya',
          onTap: () => _requestRescheduleDialog(b),
        ),
      );
    }
    if (isTutor) {
      if (b.status == 'confirmed' || b.status == 'in_progress') {
        options.add(
          SessionOption(
            icon: Icons.person_off_outlined,
            label: 'Tandai siswa tidak hadir',
            danger: true,
            onTap: () => _run(
              () => ref
                  .read(bookingRepositoryProvider)
                  .markNoShow(b.id, 'student'),
              'Siswa ditandai tidak hadir.',
            ),
          ),
        );
      }
    } else {
      if (b.status == 'confirmed' &&
          DateTime.now().isAfter(
            b.scheduledAt.add(const Duration(minutes: 15)),
          )) {
        options.add(
          SessionOption(
            icon: Icons.person_off_outlined,
            label: 'Tutor tidak hadir',
            subtitle: 'Laporkan bila tutor belum datang 15 menit',
            danger: true,
            onTap: () => _run(
              () =>
                  ref.read(bookingRepositoryProvider).markNoShow(b.id, 'tutor'),
              'Tutor ditandai tidak hadir.',
            ),
          ),
        );
      }
      if (b.status == 'completed' || b.status == 'disputed') {
        options.add(
          SessionOption(
            icon: Icons.report_outlined,
            label: 'Ajukan komplain',
            subtitle: 'Ada masalah dengan sesi ini?',
            onTap: () => _complaintDialog(b),
          ),
        );
      }
    }
    return options;
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
      () =>
          ref.read(bookingRepositoryProvider).checkin(b.id, lat: lat, lng: lng),
      'Sesi dimulai.',
    );
  }

  /// Kartu permintaan ganti hari yang masih menunggu jawaban (bila ada).
  Widget _rescheduleSection(BookingDetail b) {
    if (b.status != 'confirmed') return const SizedBox.shrink();
    final requests = ref.watch(bookingRescheduleProvider(widget.bookingId));
    RescheduleRequest? found;
    for (final r in requests.value ?? const <RescheduleRequest>[]) {
      if (r.isPending) {
        found = r;
        break;
      }
    }
    if (found == null) return const SizedBox.shrink();
    final pending = found;
    final myId = ref.read(authStateProvider).value?.session?.user.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: RescheduleCard(
        request: pending,
        isMine: pending.isMine(myId ?? ''),
        busy: _busy,
        onAccept: () => _respondReschedule(pending, accept: true),
        onReject: () => _respondReschedule(pending, accept: false),
        onCancel: () => _run(
          () => ref
              .read(bookingRepositoryProvider)
              .cancelRescheduleRequest(pending.id),
          'Pengajuan ganti hari dibatalkan.',
        ),
      ),
    );
  }

  Future<void> _respondReschedule(
    RescheduleRequest r, {
    required bool accept,
  }) async {
    String? note;
    if (!accept) {
      note = await _textDialog('Alasan menolak', 'Contoh: jadwal bentrok');
      if (note == null) return;
    }
    await _run(
      () => ref
          .read(bookingRepositoryProvider)
          .respondReschedule(r.id, accept: accept, note: note),
      accept ? 'Ganti hari disetujui.' : 'Permintaan ganti hari ditolak.',
    );
  }

  Future<void> _requestRescheduleDialog(BookingDetail b) async {
    final at = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RescheduleSheet(booking: b),
    );
    if (at == null || !mounted) return;
    final reason = await _textDialog(
      'Alasan ganti hari',
      'Contoh: ada acara keluarga (min. 5 huruf)',
    );
    if (reason == null) return;
    await _run(
      () => ref
          .read(bookingRepositoryProvider)
          .requestReschedule(b.id, at, reason),
      'Pengajuan ganti hari dikirim. Menunggu persetujuan pihak lain.',
    );
  }

  /// Tutor menjadwalkan ulang pertemuan paket yang gagal (no-show tutor).
  Future<void> _rescheduleNoShowDialog(BookingDetail b) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(b.scheduledAt),
    );
    if (time == null || !mounted) return;
    final reason = await _textDialog(
      'Alasan jadwal ulang',
      'Contoh: kendala mendadak, sesi pengganti',
    );
    if (reason == null) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await _run(
      () => ref
          .read(bookingRepositoryProvider)
          .rescheduleNoShow(b.id, at, reason),
      'Pertemuan pengganti dijadwalkan.',
    );
  }

  /// Tentor boleh mengisi/mengubah catatan selama sesi berjalan, atau
  /// setelahnya bila sesi tuntas otomatis tanpa catatan (cron H+1 tidak
  /// mewajibkan catatan).
  bool _canEditNote(BookingDetail b, bool isTutor) {
    if (!isTutor) return false;
    if (b.status == 'in_progress') return true;
    return b.status == 'completed' && b.note == null;
  }

  Future<void> _noteDialog(BookingDetail b) async {
    final material = TextEditingController(text: b.note?.material ?? '');
    final progress = TextEditingController(text: b.note?.progress ?? '');
    final nextStep = TextEditingController(text: b.note?.nextStep ?? '');
    final link = TextEditingController(text: b.meetingUrl ?? '');
    final online = b.mode == 'online';

    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Catatan sesi'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: material,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Materi yang dibahas *',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Materi wajib diisi'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: progress,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Perkembangan siswa',
                    hintText: 'Bagian yang sudah dikuasai, yang masih lemah',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: nextStep,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tugas atau saran berikutnya',
                    hintText:
                        'Contoh: kerjakan latihan bab 3, ulang materi limit',
                  ),
                ),
                if (online) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: link,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Tautan Zoom (opsional)',
                      hintText: 'https://zoom.us/j/...',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(c, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final newLink = link.text.trim();
    final linkChanged = online && newLink != (b.meetingUrl ?? '');
    await _run(() async {
      final repo = ref.read(bookingRepositoryProvider);
      await repo.saveNote(
        b.id,
        material.text.trim(),
        progress.text.trim(),
        nextStep: nextStep.text.trim(),
      );
      if (linkChanged) {
        await repo.setMeetingUrl(b.id, newLink);
      }
    }, 'Catatan tersimpan.');
  }

  /// Isi/hapus tautan Zoom tanpa menyentuh catatan (mis. sebelum sesi mulai).
  Future<void> _linkDialog(BookingDetail b) async {
    final link = TextEditingController(text: b.meetingUrl ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tautan Zoom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: link,
              keyboardType: TextInputType.url,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tautan Zoom',
                hintText: 'https://zoom.us/j/...',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hanya tautan zoom.us / zoom.com (https) yang diterima. '
              'Kosongkan untuk menghapus.',
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref
          .read(bookingRepositoryProvider)
          .setMeetingUrl(b.id, link.text.trim()),
      'Tautan Zoom disimpan.',
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
                        i <= rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Komentar (opsional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Kirim'),
            ),
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
                  DropdownMenuItem(
                    value: 'quality',
                    child: Text('Kualitas sesi'),
                  ),
                  DropdownMenuItem(value: 'schedule', child: Text('Jadwal')),
                  DropdownMenuItem(
                    value: 'tutor_absent',
                    child: Text('Tutor tidak hadir'),
                  ),
                  DropdownMenuItem(
                    value: 'student_absent',
                    child: Text('Siswa tidak hadir'),
                  ),
                  DropdownMenuItem(value: 'payment', child: Text('Pembayaran')),
                  DropdownMenuItem(value: 'other', child: Text('Lainnya')),
                ],
                onChanged: (v) => setLocal(() => category = v ?? 'quality'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: body,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ceritakan masalahnya',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Kirim'),
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    return ok == true ? ctrl.text.trim() : null;
  }
}
