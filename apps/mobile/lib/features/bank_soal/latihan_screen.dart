import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';

import '../../core/format.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import 'bank_soal_providers.dart';
import 'bank_soal_repository.dart';
import 'hasil_screen.dart';
import 'widgets/math_text.dart';
import 'widgets/question_navigator.dart';

typedef _Attempt = ({String attemptId, List<PracticeQuestion> questions});

/// Layar mengerjakan soal: satu soal per layar, dinilai di server saat
/// selesai.
///
/// Kemudahan untuk siswa:
/// - bar atas: keluar (dengan konfirmasi), nomor soal, timer tryout, dan
///   tombol Daftar soal untuk lompat ke nomor mana pun;
/// - strip progres per nomor (dijawab / ragu-ragu / belum);
/// - soal & pilihan memakai [MathText] (rumus, satuan, rumus kimia);
/// - tanda "Ragu-ragu" seperti UNBK; boleh melewati soal;
/// - sebelum dinilai ada ringkasan soal yang belum dijawab/ragu.
class LatihanScreen extends ConsumerStatefulWidget {
  const LatihanScreen({
    super.key,
    required this.topicId,
    required this.topicName,
    this.jenjang,
    this.count = 10,
    this.mode = 'latihan',
    this.durationMinutes = 20,
    this.packId,
  });

  final String? topicId;
  final String topicName;
  final String? jenjang;
  final int count;
  final String mode;
  final int durationMinutes;

  /// Isi bila mengerjakan paket soal (urutan tetap; paket gratis tanpa
  /// langganan) — menggantikan pemilihan soal acak per topik.
  final String? packId;

  @override
  ConsumerState<LatihanScreen> createState() => _LatihanScreenState();
}

class _LatihanScreenState extends ConsumerState<LatihanScreen> {
  late Future<_Attempt> _future;
  _Attempt? _data;
  final _answers = <String, String?>{};
  final _flagged = <String>{};
  final _isian = <String, TextEditingController>{};
  var _index = 0;
  var _submitting = false;
  var _done = false;
  Timer? _timer;
  var _remaining = 0;

  bool get _tryout => widget.mode == 'tryout';

  @override
  void initState() {
    super.initState();
    _future = _start();
    _future.then((data) {
      if (!mounted) return;
      _data = data;
      if (_tryout) _startTimer();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _isian.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    if (_timer != null) return;
    _remaining = widget.durationMinutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _timer?.cancel();
        _timer = null;
        setState(() => _remaining = 0);
        final data = _data;
        if (data != null) _submit(data);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<_Attempt> _start() {
    final repo = ref.read(bankSoalRepositoryProvider);
    if (widget.packId != null) return repo.startPackAttempt(widget.packId!);
    return repo.startAttempt(
      mode: widget.mode,
      topicId: widget.topicId,
      jenjang: widget.jenjang,
      count: widget.count,
    );
  }

  bool _isAnswered(PracticeQuestion q) {
    final a = _answers[q.id];
    return a != null && a.trim().isNotEmpty;
  }

  QuestionState _stateOf(PracticeQuestion q) => _flagged.contains(q.id)
      ? QuestionState.ragu
      : _isAnswered(q)
      ? QuestionState.dijawab
      : QuestionState.belum;

  void _goTo(int i) => setState(() => _index = i);

  // --- Keluar & selesai ---------------------------------------------------

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar dari latihan?'),
        content: const Text(
          'Jawabanmu belum dinilai dan tidak akan tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Keluar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Lanjut mengerjakan'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _openNavigator(_Attempt data) async {
    final picked = await showQuestionNavigator(
      context,
      states: [for (final q in data.questions) _stateOf(q)],
      current: _index,
      onFinish: () => _confirmSubmit(data),
    );
    if (picked != null && mounted) _goTo(picked);
  }

  Future<void> _confirmSubmit(_Attempt data) async {
    final belum = data.questions.where((q) => !_isAnswered(q)).length;
    final ragu = data.questions.where((q) => _flagged.contains(q.id)).length;
    final notes = [
      if (belum > 0) '$belum soal belum dijawab',
      if (ragu > 0) '$ragu soal ditandai ragu-ragu',
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Selesai & lihat nilai?'),
        content: Text(
          notes.isEmpty
              ? 'Semua soal sudah dijawab. Jawaban akan dinilai sekarang.'
              : 'Masih ada ${notes.join(' dan ')}. Soal kosong dihitung salah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(notes.isEmpty ? 'Periksa lagi' : 'Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _submit(data);
  }

  Future<void> _submit(_Attempt data) async {
    if (_submitting) return;
    _timer?.cancel();
    _timer = null;
    setState(() => _submitting = true);
    try {
      final answers = {for (final q in data.questions) q.id: _answers[q.id]};
      final result = await ref
          .read(bankSoalRepositoryProvider)
          .submitAttempt(attemptId: data.attemptId, answers: answers);
      if (!mounted) return;
      ref.invalidate(myStatsProvider);
      ref.invalidate(packsProvider);
      _done = true;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HasilScreen(
            result: result,
            questions: {for (final q in data.questions) q.id: q},
            answers: answers,
            title: _tryout ? 'Hasil Tryout' : 'Hasil Latihan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // --- Tampilan -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done || _data == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && mounted) {
          _done = true;
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    Expanded(
                      child: EmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Tidak bisa mulai latihan',
                        message: cleanError(snap.error),
                        action: OutlinedButton.icon(
                          onPressed: () => setState(() => _future = _start()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba lagi'),
                        ),
                      ),
                    ),
                  ],
                );
              }
              final data = snap.data!;
              if (data.questions.isEmpty) {
                return const EmptyState(
                  icon: Icons.quiz_outlined,
                  title: 'Belum ada soal',
                );
              }
              return _page(data);
            },
          ),
        ),
      ),
    );
  }

  Widget _page(_Attempt data) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final qs = data.questions;
    final q = qs[_index];
    final last = _index == qs.length - 1;
    final answered = qs.where(_isAnswered).length;

    return Column(
      children: [
        // Bar atas.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Keluar',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.topicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Soal ${_index + 1} dari ${qs.length}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (_tryout && _remaining > 0) ...[
                _TimerChip(seconds: _remaining),
                const SizedBox(width: 4),
              ],
              TextButton.icon(
                onPressed: () => _openNavigator(data),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: Text('$answered/${qs.length}'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: ProgressStrip(
            states: [for (final x in qs) _stateOf(x)],
            current: _index,
            onTap: _goTo,
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: ListView(
              key: ValueKey(q.id),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _QuestionCard(
                  number: _index + 1,
                  question: q,
                  flagged: _flagged.contains(q.id),
                  onFlag: () => setState(() {
                    if (!_flagged.remove(q.id)) _flagged.add(q.id);
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (q.type == 'pg') ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Pilih satu jawaban',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  for (final o in q.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                      child: _OptionCard(
                        option: o,
                        selected: _answers[q.id] == o.key,
                        onTap: () => setState(() => _answers[q.id] = o.key),
                      ),
                    ),
                ] else
                  TextField(
                    controller: _isian.putIfAbsent(
                      q.id,
                      () => TextEditingController(text: _answers[q.id]),
                    ),
                    style: theme.textTheme.titleMedium,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Jawabanmu',
                      hintText: 'Tulis jawaban singkat',
                    ),
                    onChanged: (v) => setState(() => _answers[q.id] = v),
                  ),
              ],
            ),
          ),
        ),
        // Bar bawah.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Sebelumnya'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submitting
                      ? null
                      : last
                      ? () => _confirmSubmit(data)
                      : () => _goTo(_index + 1),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: last ? palette.challenge : null,
                    foregroundColor: last ? palette.onChallenge : null,
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          last
                              ? Icons.check_rounded
                              : Icons.chevron_right_rounded,
                        ),
                  label: Text(
                    last
                        ? 'Selesai'
                        : _isAnswered(q)
                        ? 'Berikutnya'
                        : 'Lewati',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    // Warna: 1 menit terakhir = perlu perhatian → warning.
    final urgent = seconds <= 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: urgent ? palette.warningSoft : palette.brandSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: urgent ? palette.warning : palette.brand,
          ),
          const SizedBox(width: 4),
          Text(
            AppFormat.clock(seconds),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: urgent ? palette.warning : palette.brand,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu soal: nomor, tombol Ragu-ragu, isi soal (rumus terbaca), gambar.
class _QuestionCard extends ConsumerWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.flagged,
    required this.onFlag,
  });

  final int number;
  final PracticeQuestion question;
  final bool flagged;
  final VoidCallback onFlag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final image = question.imagePath;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.brandSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Soal $number',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              FilterChip(
                selected: flagged,
                onSelected: (_) => onFlag(),
                showCheckmark: false,
                avatar: Icon(
                  flagged ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                  size: 17,
                  color: flagged ? palette.warning : scheme.onSurfaceVariant,
                ),
                label: const Text('Ragu-ragu'),
                selectedColor: palette.warningSoft,
                side: BorderSide(
                  color: flagged ? palette.warning : scheme.outline,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          MathText(
            question.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              height: 1.55,
              color: scheme.onSurface,
            ),
          ),
          if (image != null && image.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _QuestionImage(path: image),
          ],
        ],
      ),
    );
  }
}

/// Gambar soal (bucket privat → URL sementara). Ketuk untuk memperbesar.
class _QuestionImage extends ConsumerWidget {
  const _QuestionImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<String?>(
      future: path.startsWith('http')
          ? Future.value(path)
          : ref.read(bankSoalRepositoryProvider).signedImageUrl(path),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) {
          return Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: snap.connectionState == ConnectionState.done
                ? const Text('Gambar tidak bisa dimuat')
                : const CircularProgressIndicator(),
          );
        }
        return GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (c) => Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Image.network(url),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.pop(c),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(url, fit: BoxFit.contain),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pilihan jawaban: kartu besar (target sentuh ≥56px), huruf di lingkaran,
/// isi memakai [MathText]. Terpilih → latar & garis brand.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final QuestionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    return Material(
      color: selected ? palette.brandSoft : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: selected ? palette.brand : scheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? palette.brand : scheme.surface,
                    border: Border.all(
                      color: selected ? palette.brand : scheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    option.key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected ? palette.onBrand : scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MathText(
                    option.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 17,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: palette.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
