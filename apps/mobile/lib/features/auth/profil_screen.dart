import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/screen_head.dart';
import '../../core/widgets/status_badge.dart';
import '../bank_soal/bank_soal_providers.dart';
import '../bank_soal/bank_soal_repository.dart';
import '../booking/booking_providers.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final isSiswa = ref.watch(appFlavorProvider) == AppFlavor.siswa;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myProfileProvider);
            ref.invalidate(mySubscriptionProvider);
            ref.invalidate(myCreditProvider);
          },
          child: AsyncView<MyProfile>(
            value: profile,
            errorTitle: 'Gagal memuat profil',
            onRetry: () => ref.invalidate(myProfileProvider),
            builder: (p) => ListView(
              padding: screenPadding,
              children: [
                ScreenHead(
                  showBack: !isSiswa,
                  eyebrow: isSiswa ? 'Akun' : 'Akun tutor',
                  title: 'Profil',
                  subtitle: isSiswa
                      ? 'Data akun dan pengaturan aplikasi.'
                      : 'Data akun dan rekening penerimaan gaji.',
                ),
                const SizedBox(height: 18),
                _ProfileCard(profile: p, isSiswa: isSiswa),
                if (isSiswa) ...[const SizedBox(height: 18), _TransaksiRow()],
                if (isSiswa) ...[const SizedBox(height: 12), const _PoinCard()],
                if (isSiswa) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Data siswa',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _DataCard(
                    rows: [
                      ('Sekolah', p.school),
                      ('Nomor HP', p.phone),
                      ('Kontak darurat', p.emergencyContactName),
                      ('Telepon darurat', p.emergencyContactPhone),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Langganan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const _SubscriptionCard(),
                ] else ...[
                  const SizedBox(height: 22),
                  Text(
                    'Data tutor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _DataCard(
                    rows: [
                      ('Nomor HP', p.phone),
                      ('Email', p.email),
                      ('Status akun', 'Tutor aktif'),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  'Pengaturan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 9),
                const _SettingsCard(),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.35),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.06),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Keluar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.isSiswa});
  final MyProfile profile;
  final bool isSiswa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.fullName ?? profile.email ?? 'Pengguna';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
                if (profile.email != null) ...[
                  const SizedBox(height: 2),
                  Text(profile.email!, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 6),
                StatusBadge(
                  label: isSiswa
                      ? 'Siswa ${profile.jenjang ?? ''}'.trim()
                      : 'Tutor',
                  tone: StatusTone.info,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pintu masuk riwayat transaksi (uang), dipisah dari agenda Jadwal.
class _TransaksiRow extends StatelessWidget {
  const _TransaksiRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      onTap: () => context.push('/riwayat-transaksi'),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 19,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat transaksi',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paket, sesi, langganan, dan kelas grup.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Saldo poin siswa (1 poin = Rp1). Poin hanya berasal dari kompensasi
/// (tutor tidak hadir atau keputusan admin) dan dipakai memotong pembayaran
/// berikutnya — tidak bisa diuangkan.
class _PoinCard extends ConsumerWidget {
  const _PoinCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final balance = ref.watch(myCreditProvider);
    final saldo = balance.value ?? 0;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.savings_rounded,
              size: 19,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Poin saya',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  balance.hasValue
                      ? '${AppFormat.rupiah(saldo)} · potong pembayaran berikutnya'
                      : balance.hasError
                      ? 'Gagal memuat saldo poin'
                      : 'Memuat saldo poin…',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            AppFormat.rupiah(saldo),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.rows});
  final List<(String, String?)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: theme.colorScheme.outline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    rows[i].$2 ?? '—',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
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

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(mySubscriptionProvider);
    return AsyncView<SubscriptionInfo?>(
      value: sub,
      errorTitle: 'Gagal memuat langganan',
      onRetry: () => ref.invalidate(mySubscriptionProvider),
      builder: (s) {
        final aktif = s?.bisaLatihan ?? false;
        final detail = switch (s?.status) {
          'active' when s?.currentPeriodEnd != null =>
            'Berlaku sampai ${AppFormat.dateShort(s!.currentPeriodEnd!)}',
          'grace' when s?.graceUntil != null =>
            'Tenggang sampai ${AppFormat.dateShort(s!.graceUntil!)}',
          _ => 'Latihan bank soal belum aktif',
        };
        return AppCard(
          onTap: () => context.go('/bank-soal'),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      (aktif
                              ? AppColors.success
                              : Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  aktif ? Icons.menu_book_rounded : Icons.lock_outline_rounded,
                  size: 19,
                  color: aktif
                      ? AppColors.success
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s?.label ?? 'Belum aktif',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (!aktif)
                TextButton(
                  onPressed: () => context.go('/bank-soal'),
                  child: const Text('Perpanjang'),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(themeModeProvider);
    final dark = ref.read(themeModeProvider.notifier).isDark(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => ref.read(themeModeProvider.notifier).toggle(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    Icons.dark_mode_outlined,
                    size: 19,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Tema gelap',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Switch(
                    value: dark,
                    onChanged: (_) =>
                        ref.read(themeModeProvider.notifier).toggle(context),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 19,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Bantuan & FAQ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 19,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Kebijakan privasi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
