import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/snap_result.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_theme.dart';

enum _QrisPhase { waiting, paid, failed, expired }

/// Menampilkan QRIS dinamis (nominal sudah tertanam) dan memantau status
/// tagihan sampai lunas. Webhook Midtrans menandai `payments` lunas beberapa
/// detik setelah dibayar; layar ini lalu menutup sendiri dengan `pop(true)`.
class QrisScreen extends StatefulWidget {
  const QrisScreen({super.key, required this.result});

  final SnapResult result;

  @override
  State<QrisScreen> createState() => _QrisScreenState();
}

class _QrisScreenState extends State<QrisScreen> with WidgetsBindingObserver {
  Timer? _poll;
  Timer? _tick;
  var _phase = _QrisPhase.waiting;
  var _checking = false;
  var _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateCountdown();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  // Siswa biasanya pindah ke aplikasi e-wallet lalu kembali: cek langsung.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _updateCountdown() {
    final expires = widget.result.expiresAt;
    if (expires == null || _phase != _QrisPhase.waiting) return;
    final left = expires.difference(DateTime.now()).inSeconds;
    setState(() => _secondsLeft = left < 0 ? 0 : left);
    // Beri jeda agar pembayaran detik terakhir sempat tercatat sebelum dinyatakan habis.
    if (left < -15) _finish(_QrisPhase.expired);
  }

  Future<void> _check() async {
    if (_checking || _phase != _QrisPhase.waiting) return;
    _checking = true;
    try {
      final status = await supabase.rpc<String?>(
        'my_payment_status',
        params: {'p_order_id': widget.result.orderId},
      );
      if (!mounted) return;
      switch (status) {
        case 'settlement' || 'capture':
          _finish(_QrisPhase.paid);
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        case 'expire':
          _finish(_QrisPhase.expired);
        case 'deny' || 'cancel':
          _finish(_QrisPhase.failed);
      }
    } catch (_) {
      // Jaringan putus sesaat: coba lagi di putaran berikutnya.
    } finally {
      _checking = false;
    }
  }

  void _finish(_QrisPhase phase) {
    _poll?.cancel();
    _tick?.cancel();
    if (mounted) setState(() => _phase = phase);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = widget.result;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Tutup',
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: const Text('Bayar dengan QRIS', style: TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.xl),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: AppRadius.card,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    'Total bayar',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppFormat.rupiah(result.amount),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  if (result.creditApplied > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sudah dipotong poin ${AppFormat.rupiah(result.creditApplied)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _QrBox(result: result, dimmed: _phase != _QrisPhase.waiting),
                  const SizedBox(height: AppSpacing.lg),
                  _StatusLine(phase: _phase, secondsLeft: _secondsLeft),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_phase == _QrisPhase.waiting) ...[
              const _Steps(),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _check,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Saya sudah bayar, cek status'),
              ),
            ] else if (_phase != _QrisPhase.paid)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Kembali'),
              ),
          ],
        ),
      ),
    );
  }
}

/// QR selalu di atas latar putih (juga di mode gelap) agar mudah dipindai.
class _QrBox extends StatelessWidget {
  const _QrBox({required this.result, required this.dimmed});

  final SnapResult result;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final Widget qr = result.qrString.isNotEmpty
        ? QrImageView(
            data: result.qrString,
            size: 240,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
          )
        : Image.network(
            result.qrUrl,
            width: 240,
            height: 240,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 240,
              height: 240,
              child: Center(child: Text('QR gagal dimuat')),
            ),
          );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: dimmed ? 0.15 : 1,
        child: qr,
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.phase, required this.secondsLeft});

  final _QrisPhase phase;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (IconData? icon, Color color, String text) = switch (phase) {
      _QrisPhase.waiting => (
          null,
          scheme.onSurfaceVariant,
          'Menunggu pembayaran · ${AppFormat.clock(secondsLeft)}',
        ),
      _QrisPhase.paid => (
          Icons.check_circle_rounded,
          Colors.green.shade600,
          'Pembayaran berhasil',
        ),
      _QrisPhase.expired => (
          Icons.timer_off_rounded,
          scheme.error,
          'QR kedaluwarsa. Silakan buat tagihan baru.',
        ),
      _QrisPhase.failed => (
          Icons.cancel_rounded,
          scheme.error,
          'Pembayaran dibatalkan.',
        ),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon == null)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  static const _items = [
    'Buka aplikasi e-wallet atau m-banking (GoPay, OVO, DANA, ShopeePay, BCA, dll).',
    'Pilih menu Scan / QRIS, lalu arahkan ke kode di atas.',
    'Nominal sudah terisi otomatis — cukup konfirmasi pembayaran.',
    'Layar ini menutup sendiri begitu pembayaran diterima.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cara bayar', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(_items[i], style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
