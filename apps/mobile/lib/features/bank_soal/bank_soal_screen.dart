import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/screen_head.dart';
import '../auth/auth_providers.dart';
import '../booking/qris_screen.dart';
import 'bank_soal_providers.dart';
import 'bank_soal_repository.dart';
import 'widgets/free_pack_card.dart';
import 'widgets/locked_sheet.dart';
import 'widgets/subject_picker.dart';
import 'widgets/subscription_card.dart';
import 'widgets/topic_panel.dart';
import 'widgets/tryout_hero.dart';

/// Bank Soal — tujuan utama: siswa mudah berpindah antar MAPEL dan melihat
/// bank soal di mapel itu.
///
/// Urutan: (belum langganan) paket coba gratis + kartu langganan, atau
/// (sudah) status ringkas → navigator mapel (jenjang + chip mapel) → panel
/// topik mapel terpilih → tryout. Topik terkunci tetap bisa diketuk untuk
/// penjelasan + jalan keluar (lihat [showLockedSheet]).
class BankSoalScreen extends ConsumerStatefulWidget {
  const BankSoalScreen({super.key});

  @override
  ConsumerState<BankSoalScreen> createState() => _BankSoalScreenState();
}

class _BankSoalScreenState extends ConsumerState<BankSoalScreen> {
  var _buying = false;
  String? _error;
  String? _jenjang;
  String? _subject;

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(mySubscriptionProvider);
    final profileJenjang = ref.watch(myProfileProvider).asData?.value.jenjang;
    final bisa = sub.asData?.value?.bisaLatihan ?? false;
    final packs = ref.watch(packsProvider).asData?.value ?? const [];
    final freePack = packs.where((p) => p.isFree).firstOrNull;
    final stats = <String, TopicStat>{
      for (final s
          in ref.watch(myStatsProvider).asData?.value ?? const <TopicStat>[])
        if (s.topicId != null) s.topicId!: s,
    };
    const gap = SizedBox(height: AppSpacing.md);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mySubscriptionProvider);
            ref.invalidate(myStatsProvider);
            ref.invalidate(catalogProvider);
            ref.invalidate(packsProvider);
          },
          child: ListView(
            padding: screenPadding,
            children: [
              const ScreenHead(
                showBack: true,
                title: 'Bank Soal',
                subtitle:
                    'Pilih mapel, lalu latihan per topik lengkap '
                    'dengan pembahasan.',
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!bisa && freePack != null) ...[
                FreePackCard(
                  pack: freePack,
                  onStart: () => _openPack(freePack),
                ),
                gap,
              ],
              AsyncView<SubscriptionInfo?>(
                value: sub,
                errorTitle: 'Gagal memuat langganan',
                onRetry: () => ref.invalidate(mySubscriptionProvider),
                builder: (s) => SubscriptionCard(
                  sub: s,
                  buying: _buying,
                  error: _error,
                  onBuy: _buy,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AsyncView<List<CatalogTopic>>(
                value: ref.watch(catalogProvider),
                errorTitle: 'Gagal memuat mapel',
                onRetry: () => ref.invalidate(catalogProvider),
                builder: (catalog) => _catalog(
                  catalog,
                  profileJenjang: profileJenjang,
                  unlocked: bisa,
                  stats: stats,
                  freePack: freePack,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TryoutHero(
                enabled: bisa,
                onTap: () => context.push(
                  '/tryout',
                  extra: {'jenjang': _jenjang ?? profileJenjang},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catalog(
    List<CatalogTopic> catalog, {
    required String? profileJenjang,
    required bool unlocked,
    required Map<String, TopicStat> stats,
    required QuestionPack? freePack,
  }) {
    if (catalog.isEmpty) {
      return Text(
        'Belum ada topik latihan.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    // Jenjang yang ada, urut SD → SMP → SMA; bawaan = jenjang profil siswa.
    final jenjangs = {for (final t in catalog) t.jenjang}.toList()
      ..sort(
        (a, b) => AppConstants.jenjang
            .indexOf(a)
            .compareTo(AppConstants.jenjang.indexOf(b)),
      );
    final jenjang = jenjangs.contains(_jenjang)
        ? _jenjang!
        : jenjangs.contains(profileJenjang)
        ? profileJenjang!
        : jenjangs.last;

    final inJenjang = catalog.where((t) => t.jenjang == jenjang).toList();
    final bySubject = <String, List<CatalogTopic>>{};
    for (final t in inJenjang) {
      bySubject.putIfAbsent(t.subjectName, () => []).add(t);
    }
    final subjects = [
      for (final e in bySubject.entries) (name: e.key, topics: e.value.length),
    ];
    // Bawaan: mapel paket gratis (bila belum langganan), selain itu mapel
    // pertama.
    final freeSubject =
        !unlocked &&
            freePack != null &&
            bySubject.containsKey(freePack.subjectName)
        ? freePack.subjectName
        : null;
    final subject = bySubject.containsKey(_subject)
        ? _subject!
        : freeSubject ?? subjects.first.name;
    final freeTopicId = freePack == null
        ? null
        : inJenjang
              .where(
                (t) =>
                    t.subjectName == freePack.subjectName &&
                    t.topicName == freePack.topicName,
              )
              .firstOrNull
              ?.topicId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubjectPicker(
          jenjangs: jenjangs,
          jenjang: jenjang,
          onJenjang: (j) => setState(() {
            _jenjang = j;
            _subject = null;
          }),
          subjects: subjects,
          selected: subject,
          onSelect: (s) => setState(() => _subject = s),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: TopicPanel(
            key: ValueKey('$jenjang/$subject'),
            subject: subject,
            topics: bySubject[subject]!,
            stats: stats,
            unlocked: unlocked,
            freeTopicId: freeTopicId,
            onOpen: _openTopic,
            onLocked: (t) => showLockedSheet(
              context,
              topic: t,
              freePack: freePack,
              price: ref.read(planProvider).asData?.value?.price,
              onFree: () {
                if (freePack != null) _openPack(freePack);
              },
              onSubscribe: _buy,
            ),
          ),
        ),
      ],
    );
  }

  void _openTopic(CatalogTopic t) {
    if (t.questionCount == 0) return;
    context.push(
      '/latihan/${t.topicId}',
      extra: {'name': t.topicName, 'jenjang': t.jenjang},
    );
  }

  void _openPack(QuestionPack p) {
    context.push(
      '/paket-soal/${p.id}',
      extra: {'name': p.topicName ?? p.title},
    );
  }

  Future<void> _buy() async {
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(bankSoalRepositoryProvider)
          .createSubscriptionSnap();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => QrisScreen(result: res)));
      if (!mounted) return;
      ref.invalidate(mySubscriptionProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }
}
