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
import 'widgets/step_progress.dart';

/// Beli paket pertemuan (4/8/12, seminggu sekali) dalam 3 langkah:
/// paket & durasi, jadwal mingguan, lalu ringkasan & pembayaran.
///
/// Layar ini hanya mengurus kerangka (head, progres, bar bawah) dan navigasi;
/// state & logika ada di [BeliPaketController], tiap langkah di `steps/`.
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
              : _buildWizard(d, busy),
        ),
      ),
      bottomNavigationBar: detail.maybeWhen(
        data: (d) => d == null ? null : _buildBottomBar(),
        orElse: () => null,
      ),
    );
  }

  Widget _buildWizard(TutorDetail detail, List<BusySlot>? busy) {
    final c = _controller;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: screenPadding,
            children: [
              ScreenHead(
                showBack: c.step == 0,
                eyebrow:
                    'Paket belajar · langkah ${c.step + 1} dari ${beliPaketStepTitles.length}',
                title: beliPaketStepTitles[c.step],
                subtitle: detail.tutor.fullName,
              ),
              const SizedBox(height: AppSpacing.lg),
              StepProgress(
                current: c.step,
                labels: beliPaketStepTitles,
                onTap: c.goTo,
              ),
              const SizedBox(height: AppSpacing.xl),
              _stepWidget(detail, busy),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepWidget(TutorDetail detail, List<BusySlot>? busy) {
    final c = _controller;
    return switch (c.step) {
      0 => StepPaket(controller: c, detail: detail),
      1 => StepJadwal(controller: c, detail: detail, busy: busy),
      _ => StepRingkasan(
        controller: c,
        onApplyVoucher: _applyVoucher,
        onClearVoucher: c.clearVoucher,
      ),
    };
  }

  // --- Bar bawah ----------------------------------------------------------

  Widget _buildBottomBar() {
    final c = _controller;
    final isLast = c.isLastStep;
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
            Row(
              children: [
                if (c.step > 0) ...[
                  AppButton(
                    label: 'Kembali',
                    expand: false,
                    variant: AppButtonVariant.secondary,
                    onPressed: c.submitting ? null : () => c.goTo(c.step - 1),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: AppButton(
                    label: _advanceLabel,
                    icon: isLast ? Icons.lock_outline_rounded : null,
                    loading: c.submitting,
                    onPressed: _canAdvance()
                        ? (isLast ? _submit : () => c.goTo(c.step + 1))
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _advanceLabel => switch (_controller.step) {
    0 => 'Lanjutkan ke jadwal',
    1 => 'Lanjut ke ringkasan',
    _ => 'Lanjut ke pembayaran',
  };

  bool _canAdvance() {
    final c = _controller;
    return switch (c.step) {
      0 => c.subject != null && c.mode != null && _packagePrice() != null,
      1 => c.slot != null && c.date != null && c.startMinutes != null,
      _ => c.mode != 'offline' || c.address.text.trim().isNotEmpty,
    };
  }

  int? _packagePrice() {
    final c = _controller;
    if (c.subject == null || c.mode == null) return null;
    return ref
        .read(
          packagePriceProvider((
            jenjang: c.subject!.jenjang,
            duration: c.duration,
            mode: c.mode!,
            totalSesi: c.size,
          )),
        )
        .asData
        ?.value;
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrisScreen(result: result),
      ),
    );
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
