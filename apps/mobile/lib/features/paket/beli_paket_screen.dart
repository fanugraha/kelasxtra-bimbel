import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_text.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../booking/booking_providers.dart';
import '../booking/snap_screen.dart';
import '../katalog/katalog_providers.dart';
import '../katalog/katalog_repository.dart';
import 'paket_providers.dart';

class BeliPaketScreen extends ConsumerStatefulWidget {
  const BeliPaketScreen({super.key, required this.tutorId});

  final String tutorId;

  @override
  ConsumerState<BeliPaketScreen> createState() => _BeliPaketScreenState();
}

class _BeliPaketScreenState extends ConsumerState<BeliPaketScreen> {
  TutorSubjectItem? _subject;
  String? _mode;
  int _duration = 60;
  int _size = 4;
  var _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(tutorDetailProvider(widget.tutorId));
    return Scaffold(
      appBar: AppBar(title: const Text('Beli Paket')),
      body: AsyncView<TutorDetail?>(
        value: detail,
        errorTitle: 'Gagal memuat data tutor',
        onRetry: () => ref.invalidate(tutorDetailProvider(widget.tutorId)),
        builder: (d) => d == null
            ? const EmptyState(
                icon: Icons.person_off_rounded,
                title: 'Tutor tidak ditemukan',
              )
            : _buildForm(d),
      ),
    );
  }

  Widget _buildForm(TutorDetail detail) {
    final theme = Theme.of(context);
    final ready = _subject != null && _mode != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Text(detail.tutor.fullName, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xl),

        _label('Mapel & Jenjang'),
        if (detail.subjects.isEmpty)
          const Text('Tutor belum mengatur mapel.')
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in detail.subjects)
                ChoiceChip(
                  label: Text('${s.subjectName} · ${s.jenjang}'),
                  selected: _subject == s,
                  onSelected: (_) => setState(() => _subject = s),
                ),
            ],
          ),

        const SizedBox(height: AppSpacing.xl),
        _label('Mode'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final m in const ['online', 'offline'])
              ChoiceChip(
                label: Text(m == 'online' ? 'Online' : 'Offline'),
                selected: _mode == m,
                onSelected: (_) => setState(() => _mode = m),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        _label('Durasi per sesi'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final d in AppConstants.durations)
              ChoiceChip(
                label: Text('$d menit'),
                selected: _duration == d,
                onSelected: (_) => setState(() => _duration = d),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        _label('Jumlah sesi'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final entry in paketSizes.entries)
              ChoiceChip(
                label: Text(entry.value == 0
                    ? '${entry.key} sesi'
                    : '${entry.key} sesi · −${entry.value}%'),
                selected: _size == entry.key,
                onSelected: (_) => setState(() => _size = entry.key),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        _TotalCard(subject: _subject, mode: _mode, duration: _duration, size: _size),

        const SizedBox(height: AppSpacing.md),
        Text(
          'Kuota paket berlaku 90 hari dan hangus bila lewat masa berlaku.',
          style: theme.textTheme.bodySmall,
        ),

        AppErrorText(_error),

        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Beli paket',
          icon: Icons.shopping_bag_outlined,
          loading: _submitting,
          onPressed: ready ? _submit : null,
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(paketRepositoryProvider).createPackageSnap(
            tutorId: widget.tutorId,
            subjectId: _subject!.subjectId,
            jenjang: _subject!.jenjang,
            durationMinutes: _duration,
            mode: _mode!,
            totalSesi: _size,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SnapScreen(redirectUrl: result.redirectUrl)),
      );
      if (!mounted) return;
      ref.invalidate(myPackagesProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _TotalCard extends ConsumerWidget {
  const _TotalCard({
    required this.subject,
    required this.mode,
    required this.duration,
    required this.size,
  });

  final TutorSubjectItem? subject;
  final String? mode;
  final int duration;
  final int size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (subject == null || mode == null) {
      return AppCard(
        child: Text('Pilih mapel dan mode untuk melihat harga.',
            style: theme.textTheme.bodySmall),
      );
    }
    final price = ref.watch(priceProvider((
      jenjang: subject!.jenjang,
      duration: duration,
      mode: mode!,
    )));
    return AppCard(
      child: price.when(
        loading: () => const SizedBox(
          height: 24,
          child: Align(alignment: Alignment.centerLeft, child: LinearProgressIndicator()),
        ),
        error: (e, _) => Text('Gagal memuat harga.\n$e', style: theme.textTheme.bodySmall),
        data: (perSession) {
          if (perSession == null) {
            return Text('Harga belum diset untuk kombinasi ini.',
                style: theme.textTheme.bodySmall);
          }
          final total = paketTotal(pricePerSession: perSession, totalSesi: size);
          final normal = perSession * size;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$size × ${AppFormat.rupiah(perSession)}',
                      style: theme.textTheme.bodySmall),
                  const Spacer(),
                  if (total < normal)
                    Text(
                      AppFormat.rupiah(normal),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(decoration: TextDecoration.lineThrough),
                    ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              Text('Total bayar', style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppFormat.rupiah(total),
                style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primary),
              ),
            ],
          );
        },
      ),
    );
  }
}
