import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_error_text.dart';
import '../../core/widgets/screen_head.dart';
import '../paket/paket_providers.dart';
import '../paket/paket_repository.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';
import 'qris_screen.dart';
import 'widgets/payment_status_widgets.dart';

/// Info yang dibutuhkan untuk membuka pembayaran paket lagi.
///
/// Midtrans Snap memakai ulang tautan tagihan yang sama selama belum lunas,
/// jadi memanggil Edge Function sekali lagi tidak membuat tagihan ganda.
class PaymentRetry {
  const PaymentRetry({required this.packageId});

  final String packageId;
}

/// Layar hasil pembayaran: menampilkan status tagihan sesudah siswa menutup
/// Snap, dan memberi jalan keluar (lihat sesi, bayar lagi, atau pesan ulang).
class PaymentStatusScreen extends ConsumerStatefulWidget {
  const PaymentStatusScreen({
    super.key,
    required this.orderId,
    this.amount,
    this.bookingId,
    this.packageId,
    this.retry,
  });

  final String orderId;
  final int? amount;
  final String? bookingId;
  final String? packageId;
  final PaymentRetry? retry;

  @override
  ConsumerState<PaymentStatusScreen> createState() =>
      _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen>
    with WidgetsBindingObserver {
  late final String? _bookingId = widget.bookingId;
  late String? _packageId = widget.packageId;

  Timer? _timer;
  int _ticks = 0;
  bool _paying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari halaman pembayaran / app lain: cek status terbaru.
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startPolling();
    }
  }

  /// Midtrans mengabari server lewat webhook; status di HP menyusul beberapa
  /// detik kemudian. Periksa berkala sampai tagihan jelas hasilnya.
  void _startPolling() {
    _timer?.cancel();
    _ticks = 0;
    _timer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final status = _status();
      final terminal = status != null && status != 'pending_payment';
      if (terminal || _ticks++ >= 40) {
        t.cancel();
        return;
      }
      // null = data belum termuat; biarkan permintaan berjalan.
      if (status == 'pending_payment') _refresh();
    });
  }

  String? _status() {
    if (widget.packageId != null) {
      final id = _packageId;
      final list = ref.read(myPackagesProvider).asData?.value ?? const [];
      for (final p in list) {
        if (p.id == id) return p.status;
      }
      return null;
    }
    final id = _bookingId;
    if (id == null) return null;
    return ref.read(bookingDetailProvider(id)).asData?.value.status;
  }

  void _refresh() {
    if (widget.packageId != null) {
      ref.invalidate(myPackagesProvider);
    } else if (_bookingId != null) {
      ref.invalidate(bookingDetailProvider(_bookingId));
    }
    ref.invalidate(myBookingsProvider);
  }

  Future<void> _payAgain() async {
    final retry = widget.retry;
    if (retry == null) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(paketRepositoryProvider)
          .resumePackageSnap(retry.packageId);
      if (!mounted) return;
      _packageId = result.packageId ?? _packageId;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QrisScreen(result: result),
        ),
      );
      if (!mounted) return;
      _refresh();
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPackage = widget.packageId != null;
    final pkgValue = isPackage ? ref.watch(myPackagesProvider) : null;

    BookingDetail? booking;
    PackageItem? paket;
    PaymentPhase phase = PaymentPhase.checking;

    if (isPackage) {
      final list = pkgValue?.asData?.value ?? const <PackageItem>[];
      for (final p in list) {
        if (p.id == _packageId) paket = p;
      }
      phase = switch (paket?.status) {
        null => PaymentPhase.checking,
        'active' => PaymentPhase.success,
        'pending_payment' => PaymentPhase.waiting,
        _ => PaymentPhase.failed,
      };
    } else if (_bookingId != null) {
      final v = ref.watch(bookingDetailProvider(_bookingId));
      booking = v.asData?.value;
      phase = switch (booking?.status) {
        null => PaymentPhase.checking,
        'confirmed' || 'in_progress' || 'completed' => PaymentPhase.success,
        'pending_payment' => PaymentPhase.waiting,
        _ => PaymentPhase.failed,
      };
    }

    final amount = widget.amount ?? paket?.priceTotal ?? booking?.price;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            ScreenHead(
              showBack: true,
              eyebrow: 'Pembayaran',
              title: _title(phase),
              subtitle: _subtitle(phase),
            ),
            const SizedBox(height: AppSpacing.xl),
            PaymentStatusHero(phase: phase, amount: amount, orderId: widget.orderId),
            const SizedBox(height: AppSpacing.md),
            if (isPackage && paket != null)
              PaymentDetailCard(
                rows: [
                  ('Jenis', 'Paket ${paket.totalSesi} pertemuan'),
                  if (paket.tutorName != null) ('Tutor', paket.tutorName!),
                  if (paket.subjectName != null)
                    ('Mapel', '${paket.subjectName} · ${paket.jenjang}'),
                  (
                    'Mode · durasi',
                    '${paket.mode == 'online' ? 'Online' : 'Offline'} · ${paket.durationMinutes} menit'
                  ),
                  ('Jadwal', paket.jadwalLabel),
                  ('Mulai', paket.mulaiLabel),
                  if (paket.status == 'active')
                    ('Berlaku sampai', paket.masaBerlakuLabel),
                ],
              )
            else if (booking != null)
              PaymentDetailCard(
                rows: [
                  ('Jenis', 'Sesi privat'),
                  ('Tutor', booking.tutorName),
                  ('Mapel', '${booking.subjectName} · ${booking.jenjang}'),
                  (
                    'Mode · durasi',
                    '${booking.mode == 'online' ? 'Online' : 'Offline'} · ${booking.durationMinutes} menit'
                  ),
                  ('Jadwal', AppFormat.dateTimeShort(booking.scheduledAt)),
                  if (booking.address != null && booking.address!.isNotEmpty)
                    ('Alamat', booking.address!),
                ],
              )
            else
              const SizedBox.shrink(),
            const SizedBox(height: AppSpacing.md),
            PaymentNextStepCard(phase: phase),
            AppErrorText(_error),
          ],
        ),
      ),
      bottomNavigationBar: _buildActions(phase, booking, paket),
    );
  }

  Widget _buildActions(PaymentPhase phase, BookingDetail? booking, PackageItem? paket) {
    final scheme = Theme.of(context).colorScheme;
    final sessionId = _bookingId;
    final canPayAgain = widget.retry != null && phase == PaymentPhase.waiting;

    final List<Widget> buttons = switch (phase) {
      PaymentPhase.success => [
          AppButton(
            label: widget.packageId != null ? 'Lihat jadwal' : 'Lihat detail sesi',
            icon: Icons.event_available_rounded,
            onPressed: widget.packageId != null
                ? () => context.go('/jadwal')
                : (sessionId == null
                    ? null
                    : () => context.push('/sesi/$sessionId')),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Kembali ke Beranda',
            variant: AppButtonVariant.ghost,
            onPressed: () => context.go('/'),
          ),
        ],
      PaymentPhase.waiting => [
          if (canPayAgain)
            AppButton(
              label: 'Bayar sekarang',
              icon: Icons.lock_outline_rounded,
              loading: _paying,
              onPressed: _payAgain,
            )
          else
            AppButton(
              label: 'Cek status',
              icon: Icons.refresh_rounded,
              onPressed: _refresh,
            ),
          if (canPayAgain) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Cek status',
              variant: AppButtonVariant.ghost,
              onPressed: _refresh,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Kembali ke Beranda',
              variant: AppButtonVariant.ghost,
              onPressed: () => context.go('/'),
            ),
          ],
        ],
      PaymentPhase.failed => [
          AppButton(
            label: widget.packageId != null ? 'Beli paket lagi' : 'Kembali ke Beranda',
            icon: widget.packageId != null ? Icons.refresh_rounded : null,
            onPressed: () => widget.packageId != null && paket?.tutorId != null
                ? context.go('/paket/beli/${paket!.tutorId}')
                : context.go('/'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Kembali ke Beranda',
            variant: AppButtonVariant.ghost,
            onPressed: () => context.go('/'),
          ),
        ],
      PaymentPhase.checking => [
          AppButton(label: 'Memeriksa status…', loading: true, onPressed: null),
        ],
    };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: buttons),
      ),
    );
  }

  String _title(PaymentPhase phase) => switch (phase) {
        PaymentPhase.checking => 'Memeriksa pembayaran',
        PaymentPhase.success => 'Pembayaran berhasil',
        PaymentPhase.waiting => 'Menunggu pembayaran',
        PaymentPhase.failed => 'Pembayaran belum berhasil',
      };

  String _subtitle(PaymentPhase phase) => switch (phase) {
        PaymentPhase.checking => 'Sebentar ya, kami sedang memastikan statusnya.',
        PaymentPhase.success =>
          'Semua pertemuan paketmu sudah tercatat. Sampai jumpa di kelas!',
        PaymentPhase.waiting =>
          'Selesaikan pembayaran sebelum batas waktu; jadwalmu masih ditahan.',
        PaymentPhase.failed => 'Tagihan ini tidak dibayar. Kamu bisa membeli paket lagi.',
      };
}
