import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_error_text.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/credit_toggle.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../booking/booking_providers.dart';
import '../booking/qris_screen.dart';
import 'kelas_grup_providers.dart';
import 'kelas_grup_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    final cls = ref.watch(groupClassProvider(widget.classId));
    final sessions = ref.watch(groupSessionsProvider(widget.classId));
    final mySeat = ref.watch(myGroupSeatProvider(widget.classId));

    return Scaffold(
      body: SafeArea(
        child: AsyncView<GroupClassItem?>(
          value: cls,
          errorTitle: 'Gagal memuat kelas',
          onRetry: () => ref.invalidate(groupClassProvider(widget.classId)),
          builder: (c) => c == null
              ? const EmptyState(
                  icon: Icons.groups_rounded,
                  title: 'Kelas tidak ditemukan',
                )
              : _buildBody(c, sessions, mySeat),
        ),
      ),
    );
  }

  Widget _buildBody(
    GroupClassItem c,
    AsyncValue<List<GroupSessionItem>> sessions,
    AsyncValue<GroupSeatItem?> mySeat,
  ) {
    final theme = Theme.of(context);
    final seat = mySeat.asData?.value;
    final bisaAmbil = c.dibuka && !c.penuh && seat == null;

    return ListView(
      padding: screenPadding,
      children: [
        const ScreenHead(
          showBack: true,
          eyebrow: 'Kelas grup',
          title: 'Detail program',
          subtitle: 'Lihat jadwal, kursi, dan rincian biaya.',
        ),
        const SizedBox(height: 18),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${c.seatsTaken}/${c.maxSeats} kursi terisi',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    'minimal ${c.minSeats}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: c.maxSeats == 0 ? 0 : c.seatsTaken / c.maxSeats,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Kelas jalan bila minimal ${c.minSeats} kursi terisi sebelum '
                '${AppFormat.dateShort(c.minConfirmDeadline)} 20:00.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        Text(
          'Jadwal ${c.totalSesi} pertemuan',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        sessions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Gagal memuat jadwal.\n$e',
            style: theme.textTheme.bodySmall,
          ),
          data: (list) => Column(
            children: [
              for (final s in ([
                ...list,
              ]..sort((a, b) => a.seq.compareTo(b.seq))))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Text(
                      '${s.seq}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(AppFormat.dateTimeShort(s.scheduledAt)),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${c.totalSesi} × ${AppFormat.rupiah(c.pricePerSession)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (c.discountPercent > 0)
                    Text(
                      '−${c.discountPercent}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              Text(
                'Bayar sekali untuk seluruh program',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppFormat.rupiah(c.priceTotal),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        if (seat != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Kursimu: ${seat.statusLabel}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],

        AppErrorText(_error),

        if (bisaAmbil) ...[
          const SizedBox(height: AppSpacing.lg),
          CreditToggle(
            value: _useCredits,
            onChanged: (v) => setState(() => _useCredits = v),
            total: c.priceTotal,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Ambil kursi · ${AppFormat.rupiah(c.priceTotal)}',
            icon: Icons.event_seat_rounded,
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Kursi ditahan 30 menit saat kamu lanjut ke pembayaran.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ] else if (seat == null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              c.penuh
                  ? 'Kursi sudah penuh.'
                  : 'Kelas sudah jalan — kursi ditutup.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submit() async {
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
      if (res.paid) {
        ref.invalidate(myGroupSeatProvider(widget.classId));
        ref.invalidate(groupClassProvider(widget.classId));
        ref.invalidate(groupClassesProvider);
        ref.invalidate(myGroupSeatsProvider);
        ref.invalidate(myCreditProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kursi terkonfirmasi — lunas dengan poin.'),
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QrisScreen(result: res),
        ),
      );
      if (!mounted) return;
      ref.invalidate(myGroupSeatProvider(widget.classId));
      ref.invalidate(groupClassProvider(widget.classId));
      ref.invalidate(groupClassesProvider);
      ref.invalidate(myGroupSeatsProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
