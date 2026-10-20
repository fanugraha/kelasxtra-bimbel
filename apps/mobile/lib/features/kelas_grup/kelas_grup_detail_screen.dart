import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/credit_toggle.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/person_photo.dart';
import '../../core/widgets/screen_head.dart';
import '../booking/booking_providers.dart';
import '../booking/qris_screen.dart';
import 'kelas_grup_providers.dart';
import 'kelas_grup_repository.dart';
import 'widgets/seat_row.dart';

/// Detail program Belajar bareng — SATU halaman berisi semua yang perlu
/// diketahui, lalu dua ketukan sampai bayar:
///   Ambil kursi → lembar konfirmasi (ringkasan + poin) → Bayar QRIS.
///
/// Aturan yang ditampilkan jelas ke siswa:
/// - jadwal TETAP mengikuti grup (tidak bisa dipilih);
/// - kursi ditahan 5 menit saat bayar, baru "terisi" setelah lunas;
/// - kelas jalan bila kuota minimum terpenuhi, bila tidak dana kembali.
/// Perebutan kursi terakhir diselesaikan server (kunci baris kelas).
class KelasGrupDetailScreen extends ConsumerStatefulWidget {
  const KelasGrupDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  ConsumerState<KelasGrupDetailScreen> createState() =>
      _KelasGrupDetailScreenState();
}

class _KelasGrupDetailScreenState extends ConsumerState<KelasGrupDetailScreen> {
  var _submitting = false;
  var _useCredits = false;
  String? _error;
  Timer? _tick;
  var _ticks = 0;

  @override
  void initState() {
    super.initState();
    // Hitung mundur tahanan + segarkan kursi tiap 20 dtk (kursi yang ditahan
    // orang lain bisa kosong lagi).
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _ticks++;
      if (_ticks % 20 == 0) _refresh();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(groupClassProvider(widget.classId));
    ref.invalidate(myGroupSeatProvider(widget.classId));
  }

  void _refreshAll() {
    _refresh();
    ref.invalidate(groupClassesProvider);
    ref.invalidate(myGroupSeatsProvider);
    ref.invalidate(myCreditProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cls = ref.watch(groupClassProvider(widget.classId));
    final seat = ref.watch(myGroupSeatProvider(widget.classId)).asData?.value;

    return Scaffold(
      body: SafeArea(
        child: AsyncView<GroupClassItem?>(
          value: cls,
          errorTitle: 'Gagal memuat program',
          onRetry: _refresh,
          builder: (c) => c == null
              ? const EmptyState(
                  icon: Icons.groups_rounded,
                  title: 'Program tidak ditemukan',
                  message: 'Mungkin sudah ditutup atau dibatalkan.',
                )
              : _body(c, seat),
        ),
      ),
      bottomNavigationBar: cls.asData?.value == null
          ? null
          : _bottomBar(cls.asData!.value!, seat),
    );
  }

  Widget _body(GroupClassItem c, GroupSeatItem? seat) {
    final sessions = ref.watch(groupSessionsProvider(widget.classId));
    const gap = SizedBox(height: AppSpacing.md);
    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: ListView(
        padding: screenPadding,
        children: [
          ScreenHead(
            showBack: true,
            title: c.subjectName ?? 'Belajar bareng',
            subtitle:
                'Belajar bareng · ${c.jenjang} · '
                '${c.mode == 'online' ? 'Online' : 'Tatap muka'} · '
                '${c.durationMinutes} menit/sesi',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (seat != null) ...[_MySeatBanner(seat: seat), gap],
          _SeatsCard(c: c, mine: seat?.status == 'active'),
          gap,
          _TutorCard(c: c),
          gap,
          _ScheduleCard(c: c, sessions: sessions),
          gap,
          const _RulesCard(),
          gap,
          _PriceCard(c: c),
          if (_error != null) ...[
            gap,
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  // --- Bar bawah ----------------------------------------------------------

  Widget? _bottomBar(GroupClassItem c, GroupSeatItem? seat) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    String label;
    VoidCallback? action;
    if (seat?.status == 'active') {
      return null; // sudah terdaftar — banner di atas sudah menjelaskan.
    } else if (seat != null && seat.holdAlive) {
      final left = seat.lockExpiresAt!.difference(DateTime.now());
      label = 'Lanjutkan bayar · ${AppFormat.clock(left.inSeconds)}';
      action = _pay;
    } else if (!c.dibuka) {
      label = 'Pendaftaran ditutup';
    } else if (c.tertahanSemua) {
      label = 'Kursi sedang dibayar orang lain';
    } else if (c.penuh) {
      label = 'Kursi penuh';
    } else {
      label = 'Ambil kursi';
      action = () => _openConfirm(c);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bayar sekali · ${c.totalSesi} pertemuan',
                    style: theme.textTheme.labelSmall,
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppFormat.rupiah(c.priceTotal),
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
              child: FilledButton(
                onPressed: _submitting ? null : action,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(label, textAlign: TextAlign.center, maxLines: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Konfirmasi & bayar -------------------------------------------------

  Future<void> _openConfirm(GroupClassItem c) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final theme = Theme.of(ctx);
          final palette = ctx.palette;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Konfirmasi kursi',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SummaryLine(
                    'Program',
                    '${c.subjectName ?? '-'} · ${c.jenjang}',
                  ),
                  _SummaryLine('Tutor', c.tutorName ?? '-'),
                  _SummaryLine(
                    'Jadwal',
                    c.firstSession == null
                        ? '${c.totalSesi} pertemuan'
                        : '${c.totalSesi} pertemuan · mulai '
                              '${AppFormat.dateShort(c.firstSession!)}',
                  ),
                  _SummaryLine('Total', AppFormat.rupiah(c.priceTotal)),
                  const SizedBox(height: AppSpacing.sm),
                  CreditToggle(
                    value: _useCredits,
                    onChanged: (v) {
                      setState(() => _useCredits = v);
                      setSheet(() {});
                    },
                    total: c.priceTotal,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: palette.infoSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: palette.info,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Kursimu ditahan 5 menit. Selesaikan pembayaran '
                            'QRIS dalam waktu itu — kursi baru terisi setelah '
                            'pembayaran berhasil.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('Tahan kursi & bayar QRIS'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (go == true) await _pay();
  }

  Future<void> _pay() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(kelasGrupRepositoryProvider)
          .createSeatSnap(
            groupClassId: widget.classId,
            useCredits: _useCredits,
          );
      if (!mounted) return;
      if (!res.paid) {
        // Tahanan baru dibuat: segarkan agar banner "Menunggu bayar" muncul.
        _refresh();
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => QrisScreen(result: res)));
        if (!mounted) return;
      }
      _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.paid
                ? 'Kursi terkonfirmasi — lunas dengan poin.'
                : 'Status kursi diperbarui.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _refresh();
      setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ─────────────────────────── Bagian-bagian ───────────────────────────

class _Box extends StatelessWidget {
  const _Box({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
        border: color == null ? Border.all(color: scheme.outline) : null,
      ),
      child: child,
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.palette.brand),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _MySeatBanner extends StatelessWidget {
  const _MySeatBanner({required this.seat});

  final GroupSeatItem seat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final (icon, color, bg, title, body) = switch (seat.status) {
      'active' => (
        Icons.verified_rounded,
        palette.success,
        palette.successSoft,
        'Kursimu sudah terkonfirmasi',
        'Sampai jumpa di pertemuan pertama. Jadwal lengkap ada di bawah.',
      ),
      'pending_payment' when seat.holdAlive => (
        Icons.hourglass_top_rounded,
        palette.warning,
        palette.warningSoft,
        'Kursi ditahan untukmu',
        'Selesaikan pembayaran sebelum waktu habis, atau kursi dilepas.',
      ),
      'refund_pending' => (
        Icons.undo_rounded,
        palette.info,
        palette.infoSoft,
        'Dana sedang dikembalikan',
        'Kuota minimum tidak terpenuhi, kelas batal.',
      ),
      _ => (
        Icons.info_outline_rounded,
        palette.info,
        palette.infoSoft,
        'Kursi: ${seat.statusLabel}',
        'Tahanan sebelumnya sudah habis. Kamu bisa ambil kursi lagi.',
      ),
    };
    return _Box(
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatsCard extends StatelessWidget {
  const _SeatsCard({required this.c, required this.mine});

  final GroupClassItem c;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final kurang = (c.minSeats - c.terisi).clamp(0, c.minSeats);
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Head(
            icon: Icons.event_seat_rounded,
            title: '${c.terisi} dari ${c.maxSeats} kursi terisi',
          ),
          SeatRow(
            max: c.maxSeats,
            paid: c.terisi,
            held: c.seatsHeld,
            size: 38,
            mine: mine,
          ),
          const SizedBox(height: AppSpacing.sm),
          SeatLegend(held: c.seatsHeld),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  kurang == 0 ? Icons.check_circle_rounded : Icons.flag_rounded,
                  size: 18,
                  color: kurang == 0 ? palette.success : palette.brand,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    kurang == 0
                        ? 'Kuota minimum tercapai — kelas pasti jalan.'
                        : 'Butuh $kurang siswa lagi agar kelas jalan '
                              '(batas ${AppFormat.dateShort(c.minConfirmDeadline)}).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorCard extends StatelessWidget {
  const _TutorCard({required this.c});

  final GroupClassItem c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final bio = c.tutorBio?.trim();
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Head(
            icon: Icons.person_rounded,
            title: 'Kenalan dengan tutor',
          ),
          Row(
            children: [
              PersonPhoto(
                name: c.tutorName ?? 'T',
                photoUrl: c.tutorPhotoUrl,
                subjectLine: c.subjectName,
                size: 64,
                radius: 20,
                showVerified: true,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tutorName ?? '-',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((c.tutorEducation ?? '').isNotEmpty)
                      Text(
                        c.tutorEducation!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (c.tutorRating != null && c.tutorRating! > 0)
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: palette.reward,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            c.tutorRating!
                                .toStringAsFixed(1)
                                .replaceAll('.', ','),
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              bio,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
          if (c.tutorId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/tutor/${c.tutorId}'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Lihat profil lengkap tutor'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.c, required this.sessions});

  final GroupClassItem c;
  final AsyncValue<List<GroupSessionItem>> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Head(
            icon: Icons.calendar_month_rounded,
            title: 'Jadwal tetap · ${c.totalSesi} pertemuan',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text('Ikut grup', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ),
          Text(
            'Jadwal ditentukan untuk semua anggota grup dan tidak bisa '
            'dipilih atau diubah.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          sessions.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) =>
                Text('Gagal memuat jadwal.', style: theme.textTheme.bodySmall),
            data: (list) {
              final sorted = [...list]..sort((a, b) => a.seq.compareTo(b.seq));
              if (sorted.isEmpty) {
                return Text(
                  'Jadwal segera diumumkan admin.',
                  style: theme.textTheme.bodySmall,
                );
              }
              return Column(
                children: [
                  for (final s in sorted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.brandSoft,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${s.seq}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: palette.brand,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              AppFormat.dateLong(s.scheduledAt),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            AppFormat.timeRangeFrom(
                              s.scheduledAt,
                              c.durationMinutes,
                            ),
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    const rules = [
      (Icons.lock_clock_rounded, 'Jadwal mengikuti grup, tidak bisa dipilih.'),
      (
        Icons.hourglass_top_rounded,
        'Kursi ditahan 5 menit saat bayar. Kursi baru terisi setelah pembayaran berhasil.',
      ),
      (
        Icons.groups_rounded,
        'Kelas jalan bila kuota minimum terpenuhi. Bila tidak, dana kembali penuh.',
      ),
    ];
    return _Box(
      color: palette.infoSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Aturan belajar bareng',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(r.$1, size: 17, color: palette.info),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.c});

  final GroupClassItem c;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final normal = c.pricePerSession * c.totalSesi;
    final hemat = normal - c.priceTotal;
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Head(icon: Icons.receipt_long_rounded, title: 'Rincian biaya'),
          _SummaryLine(
            '${c.totalSesi} × ${AppFormat.rupiah(c.pricePerSession)}',
            AppFormat.rupiah(normal),
          ),
          if (hemat > 0)
            _SummaryLine(
              'Diskon belajar bareng ${c.discountPercent}%',
              '−${AppFormat.rupiah(hemat)}',
              color: palette.promo,
            ),
          const Divider(height: AppSpacing.xl),
          _SummaryLine('Total', AppFormat.rupiah(c.priceTotal), strong: true),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value, {this.color, this.strong = false});

  final String label;
  final String value;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: strong
                  ? theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            style:
                (strong
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                      color: color ?? theme.colorScheme.onSurface,
                    ),
          ),
        ],
      ),
    );
  }
}
