import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_text.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../booking/snap_screen.dart';
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
  String? _error;

  @override
  Widget build(BuildContext context) {
    final cls = ref.watch(groupClassProvider(widget.classId));
    final sessions = ref.watch(groupSessionsProvider(widget.classId));
    final mySeat = ref.watch(myGroupSeatProvider(widget.classId));

    return Scaffold(
      appBar: AppBar(title: const Text('Kelas Grup')),
      body: AsyncView<GroupClassItem?>(
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Text(c.tutorName ?? 'Tutor', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${c.subjectName ?? '-'} · ${c.jenjang} · ${c.durationMinutes} menit · '
          '${c.mode == 'online' ? 'Online' : 'Offline'}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${c.seatsTaken}/${c.maxSeats} kursi terisi',
                      style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text('minimal ${c.minSeats}', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: c.maxSeats == 0 ? 0 : c.seatsTaken / c.maxSeats,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
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
        Text('Jadwal ${c.totalSesi} pertemuan', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        sessions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Gagal memuat jadwal.\n$e',
              style: theme.textTheme.bodySmall),
          data: (list) => Column(
            children: [
              for (final s in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Text('${s.seq}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
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
                  Text('${c.totalSesi} × ${AppFormat.rupiah(c.pricePerSession)}',
                      style: theme.textTheme.bodySmall),
                  const Spacer(),
                  if (c.discountPercent > 0)
                    Text('−${c.discountPercent}%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.success)),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              Text('Bayar sekali untuk seluruh program', style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppFormat.rupiah(c.priceTotal),
                style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),

        if (seat != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Text('Kursimu: ${seat.statusLabel}', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],

        AppErrorText(_error),

        if (bisaAmbil) ...[
          const SizedBox(height: AppSpacing.lg),
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
              c.penuh ? 'Kursi sudah penuh.' : 'Kelas sudah jalan — kursi ditutup.',
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
          .createSeatSnap(groupClassId: widget.classId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SnapScreen(redirectUrl: res.redirectUrl)),
      );
      if (!mounted) return;
      ref.invalidate(myGroupSeatProvider(widget.classId));
      ref.invalidate(groupClassProvider(widget.classId));
      ref.invalidate(groupClassesProvider);
      ref.invalidate(myGroupSeatsProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
