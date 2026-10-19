import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/format.dart';
import '../../booking/booking_providers.dart';
import '../../booking/payment_status_screen.dart';
import '../../booking/qris_screen.dart';
import '../../katalog/katalog_providers.dart';
import '../../katalog/katalog_repository.dart';
import '../paket_providers.dart';
import '../paket_repository.dart';
import 'beli_paket_controller.dart';
import 'steps/step_atur_kelas.dart';
import 'steps/step_pembayaran.dart';
import 'widgets/checkout_parts.dart';

/// Beli paket pertemuan (4/8/12, seminggu sekali) dalam DUA langkah:
/// 1. Atur kelas — mapel, metode, durasi, jumlah pertemuan, jadwal (+ alamat).
/// 2. Ringkasan — cek pilihan, voucher/poin, rincian biaya, lalu bayar QRIS.
///
/// Layar ini hanya mengurus kerangka (bar atas, langkah, bar bawah) dan aksi;
/// state & logika ada di [BeliPaketController], tiap langkah di `steps/`.
class BeliPaketScreen extends ConsumerStatefulWidget {
  const BeliPaketScreen({super.key, required this.tutorId});

  final String tutorId;

  @override
  ConsumerState<BeliPaketScreen> createState() => _BeliPaketScreenState();
}

class _BeliPaketScreenState extends ConsumerState<BeliPaketScreen> {
  late final BeliPaketController _controller;

  /// 0 = Atur kelas, 1 = Ringkasan pembayaran.
  var _step = 0;
  final _scroll = ScrollController();

  void _goTo(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

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
    _scroll.dispose();
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
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(0);
      },
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildPage(TutorDetail detail, List<BusySlot>? busy) {
    final c = _controller;
    _autoSelect(detail);
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _TopBar(
          title: _step == 0 ? 'Atur kelas' : 'Ringkasan pembayaran',
          onBack: () => _step == 0 ? context.pop() : _goTo(0),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: CheckoutStepper(current: _step),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_step == 0)
          StepAturKelas(
            controller: c,
            detail: detail,
            busy: busy,
            mine: _mySessions(),
          )
        else
          StepPembayaran(
            controller: c,
            detail: detail,
            amounts: _amounts(watch: true),
            onEdit: () => _goTo(0),
            onApplyVoucher: _applyVoucher,
            onClearVoucher: c.clearVoucher,
          ),
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

  /// Harga paket → voucher → perkiraan poin → yang dibayar. Potongan poin
  /// final tetap dihitung server (maks. sebesar tagihan).
  CheckoutAmounts _amounts({bool watch = false}) {
    final c = _controller;
    final price = _packagePrice(watch: watch);
    if (price == null) return (price: null, discount: 0, credits: 0, pay: null);
    final discount = c.voucherDiscount.clamp(0, price);
    final afterVoucher = price - discount;
    final balance = c.useCredits
        ? (watch ? ref.watch(myCreditProvider) : ref.read(myCreditProvider))
                  .value ??
              0
        : 0;
    final credits = balance.clamp(0, afterVoucher);
    return (
      price: price,
      discount: discount,
      credits: credits,
      pay: afterVoucher - credits,
    );
  }

  // --- Bar bawah ----------------------------------------------------------

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = _controller;
    final a = _amounts(watch: true);
    final missing = _missing;
    final ready = missing == null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        // Langkah 1: tombol saja (label = isian yang belum lengkap). Total
        // baru tampil di langkah 2, bersama tombol bayar.
        child: _step == 0
            ? AppButton(
                label: missing ?? 'Lanjut ke ringkasan',
                icon: ready ? Icons.arrow_forward_rounded : null,
                onPressed: ready ? () => _goTo(1) : null,
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total pembayaran',
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            a.pay == null ? '—' : AppFormat.rupiah(a.pay!),
                            maxLines: 1,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Bayar QRIS',
                      icon: Icons.qr_code_2_rounded,
                      loading: c.submitting,
                      onPressed: ready ? _submit : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Apa yang belum diisi (jadi label tombol), atau null bila siap lanjut.
  String? get _missing {
    final c = _controller;
    if (c.subject == null) return 'Pilih mapel';
    if (c.mode == null) return 'Pilih metode';
    if (_packagePrice(watch: true) == null) return 'Harga belum ada';
    if (c.date == null || c.startMinutes == null) return 'Pilih jadwal';
    if (c.mode == 'offline' && c.address.text.trim().isEmpty) {
      return 'Isi alamat';
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

/// Bar atas: tombol kembali bulat + judul langkah di tengah.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            backgroundColor: scheme.surface,
            side: BorderSide(color: scheme.outline),
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}
