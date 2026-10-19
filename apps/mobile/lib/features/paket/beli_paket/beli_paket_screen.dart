import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_head.dart';
import '../../booking/booking_providers.dart';
import '../../booking/payment_status_screen.dart';
import '../../booking/qris_screen.dart';
import '../../katalog/katalog_providers.dart';
import '../../katalog/katalog_repository.dart';
import '../paket_providers.dart';
import '../paket_repository.dart';
import 'beli_paket_controller.dart';
import 'steps/step_jadwal.dart';
import 'steps/step_paket.dart';
import 'steps/step_ringkasan.dart';
import 'widgets/bar_total.dart';

/// Beli paket pertemuan (4/8/12, seminggu sekali) dalam satu halaman:
/// paket, jadwal mingguan, lalu bayar dengan QRIS dari bar bawah.
///
/// Layar ini hanya mengurus kerangka (head, bar bawah) dan aksi; state &
/// logika ada di [BeliPaketController], tiap bagian di `steps/`.
class BeliPaketScreen extends ConsumerStatefulWidget {
  const BeliPaketScreen({super.key, required this.tutorId});

  final String tutorId;

  @override
  ConsumerState<BeliPaketScreen> createState() => _BeliPaketScreenState();
}

class _BeliPaketScreenState extends ConsumerState<BeliPaketScreen> {
  late final BeliPaketController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BeliPaketController(
      tutorId: widget.tutorId,
      repository: ref.read(paketRepositoryProvider),
      invalidateBusy: () {
        if (mounted) ref.invalidate(tutorBusyProvider(widget.tutorId));
      },
    )..addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(tutorDetailProvider(widget.tutorId));
    final busyAsync = ref.watch(tutorBusyProvider(widget.tutorId));
    // null = masih dimuat; error diperlakukan "tanpa bentrok" agar tidak buntu
    // (server tetap memvalidasi saat submit).
    final busy =
        busyAsync.asData?.value ??
        (busyAsync.hasError ? const <BusySlot>[] : null);
    return Scaffold(
      body: SafeArea(
        child: AsyncView<TutorDetail?>(
          value: detail,
          errorTitle: 'Gagal memuat data tutor',
          onRetry: () => ref.invalidate(tutorDetailProvider(widget.tutorId)),
          builder: (d) => d == null
              ? const EmptyState(
                  icon: Icons.person_off_rounded,
                  title: 'Tutor tidak ditemukan',
                )
              : _buildPage(d, busy),
        ),
      ),
      bottomNavigationBar: detail.maybeWhen(
        data: (d) => d == null ? null : _buildBottomBar(),
        orElse: () => null,
      ),
    );
  }

  Widget _buildPage(TutorDetail detail, List<BusySlot>? busy) {
    final c = _controller;
    _autoSelect(detail);
    return ListView(
      padding: screenPadding,
      children: [
        ScreenHead(
          showBack: true,
          eyebrow: 'Beli paket',
          title: detail.tutor.fullName,
          subtitle: 'Pilih paket dan jadwal, lalu bayar dengan QRIS.',
        ),
        const SizedBox(height: AppSpacing.xl),
        StepPaket(controller: c, detail: detail),
        const SizedBox(height: AppSpacing.xl),
        StepJadwal(
          controller: c,
          detail: detail,
          busy: busy,
          mine: _mySessions(),
        ),
        const SizedBox(height: AppSpacing.xl),
        StepRingkasan(
          controller: c,
          onApplyVoucher: _applyVoucher,
          onClearVoucher: c.clearVoucher,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// Mapel & mode langsung terpilih bila tutor hanya punya satu pilihan.
  void _autoSelect(TutorDetail detail) {
    final c = _controller;
    final modes = c.availableModes(detail.availability);
    if (c.subject != null && c.mode != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (c.subject == null && detail.subjects.length == 1) {
        c.selectSubject(detail.subjects.single);
      }
      if (c.mode == null && modes.length == 1) c.selectMode(modes.single);
    });
  }

  /// Les siswa yang masih berjalan/menunggu bayar — tidak boleh ditabrak.
  List<MySession> _mySessions() {
    final mine = ref.watch(myBookingsProvider).asData?.value ?? const [];
    return [
      for (final b in mine)
        if (b.status == 'confirmed' ||
            b.status == 'in_progress' ||
            b.status == 'pending_payment')
          (
            start: b.scheduledAt,
            end: b.scheduledAt.add(Duration(minutes: b.durationMinutes)),
            label: '${b.subjectName} · ${b.tutorName}',
          ),
    ];
  }

  // --- Bar bawah ----------------------------------------------------------

  Widget _buildBottomBar() {
    final c = _controller;
    final showTotal = c.subject != null && c.mode != null;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTotal) ...[
              BarTotal(
                subject: c.subject!,
                mode: c.mode!,
                duration: c.duration,
                size: c.size,
                discount: c.voucherDiscount,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(
              label: _missing ?? 'Bayar dengan QRIS',
              icon: _missing == null ? Icons.qr_code_2_rounded : null,
              loading: c.submitting,
              onPressed: _missing == null ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Apa yang belum diisi (jadi label tombol), atau null bila siap bayar.
  String? get _missing {
    final c = _controller;
    if (c.subject == null) return 'Pilih mata pelajaran';
    if (c.mode == null) return 'Pilih mode belajar';
    if (_packagePrice(watch: true) == null) return 'Harga paket belum tersedia';
    if (c.date == null || c.startMinutes == null) {
      return 'Pilih jadwal mingguan';
    }
    if (c.mode == 'offline' && c.address.text.trim().isEmpty) {
      return 'Isi alamat belajar';
    }
    return null;
  }

  /// [watch] dipakai dari build agar tombol ikut aktif begitu harga selesai
  /// dimuat; dari callback cukup `read`.
  int? _packagePrice({bool watch = false}) {
    final c = _controller;
    if (c.subject == null || c.mode == null) return null;
    final provider = packagePriceProvider((
      jenjang: c.subject!.jenjang,
      duration: c.duration,
      mode: c.mode!,
      totalSesi: c.size,
    ));
    return (watch ? ref.watch(provider) : ref.read(provider)).asData?.value;
  }

  // --- Aksi ---------------------------------------------------------------

  Future<void> _applyVoucher() async {
    await _controller.applyVoucher(_controller.voucher.text, _packagePrice());
  }

  Future<void> _submit() async {
    final result = await _controller.submit();
    if (!mounted) return;
    if (result == null) {
      await _showErrorDialog(_controller.error ?? 'Gagal memulai pembayaran.');
      return;
    }
    if (result.paid) {
      ref.invalidate(myPackagesProvider);
      ref.invalidate(myCreditProvider);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lunas dengan poin'),
          content: const Text(
            'Paket aktif tanpa pembayaran. Poinmu sudah terpakai dan jadwal '
            'pertemuan sudah ditahan sesuai jadwal mingguan.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Lihat paket'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.pushReplacement('/paket');
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QrisScreen(result: result)));
    if (!mounted) return;
    ref.invalidate(myPackagesProvider);
    context.pushReplacement(
      '/pembayaran',
      extra: {
        'orderId': result.orderId,
        'amount': result.amount,
        'packageId': result.packageId,
        'retry': PaymentRetry(packageId: result.packageId!),
      },
    );
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tidak bisa melanjutkan'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}
