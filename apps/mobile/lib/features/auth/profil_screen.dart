import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_flavor.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/screen_head.dart';
import '../bank_soal/bank_soal_providers.dart';
import '../booking/booking_providers.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

/// Profil = biodata pengguna + pintu ke dompet/aktivitas + keamanan akun.
///
/// Urutan (siswa): kartu identitas (foto bisa diganti, tombol Edit biodata)
/// → Dompet & aktivitas (poin, riwayat transaksi, langganan) → Biodata →
/// Keamanan akun (email, ubah password) → Pengaturan → Keluar.
/// Tutor memakai layar yang sama tanpa bagian khusus siswa.
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
                ScreenHead(showBack: !isSiswa, title: 'Profil'),
                const SizedBox(height: AppSpacing.lg),
                _IdentityCard(profile: p, isSiswa: isSiswa),
                if (isSiswa) ...[
                  const _Title('Dompet & aktivitas'),
                  const _WalletCard(),
                ],
                const _Title('Biodata'),
                _BiodataCard(profile: p, isSiswa: isSiswa),
                const _Title('Keamanan akun'),
                _SecurityCard(email: p.email),
                const _Title('Pengaturan'),
                const _SettingsCard(),
                const SizedBox(height: AppSpacing.xl),
                const _LogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 9),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// Kartu dasar semua bagian profil.
class _Box extends StatelessWidget {
  const _Box({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
        border: Border.all(color: scheme.outline),
      ),
      child: child,
    );
  }
}

// ─────────────────────────── Identitas ───────────────────────────

class _IdentityCard extends ConsumerStatefulWidget {
  const _IdentityCard({required this.profile, required this.isSiswa});

  final MyProfile profile;
  final bool isSiswa;

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
  var _uploading = false;

  Future<void> _changePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      await ref.read(authRepositoryProvider).uploadAvatar(bytes, ext: ext);
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto profil diperbarui.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final p = widget.profile;
    final name = (p.fullName ?? '').trim().isEmpty ? 'Pengguna' : p.fullName!;
    final initial = name.trim()[0].toUpperCase();
    final url = p.avatarUrl;
    final role = widget.isSiswa
        ? [
            'Siswa${p.jenjang == null ? '' : ' ${p.jenjang}'}',
            if ((p.school ?? '').isNotEmpty) p.school!,
          ].join(' · ')
        : 'Tutor';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      decoration: BoxDecoration(
        color: palette.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: _uploading ? null : _changePhoto,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: palette.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 3),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Text(
                              initial,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: palette.onBrand,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (url != null && url.isNotEmpty)
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) =>
                                  const SizedBox.shrink(),
                            ),
                          if (_uploading)
                            const ColoredBox(
                              color: Color(0x66000000),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Material(
                      color: scheme.surface,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploading ? null : _changePhoto,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 16,
                            color: palette.brand,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (p.email != null)
                      Text(
                        p.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: palette.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/profil/edit'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit biodata'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Dompet & aktivitas ───────────────────────────

class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final credit = ref.watch(myCreditProvider);
    final sub = ref.watch(mySubscriptionProvider).asData?.value;
    final aktif = sub?.bisaLatihan ?? false;
    final subDetail = switch (sub?.status) {
      'active' when sub?.currentPeriodEnd != null =>
        'Aktif sampai ${AppFormat.dateShort(sub!.currentPeriodEnd!)}',
      'grace' when sub?.graceUntil != null =>
        'Tenggang sampai ${AppFormat.dateShort(sub!.graceUntil!)}',
      _ => 'Belum berlangganan',
    };

    return _Box(
      child: Column(
        children: [
          _NavRow(
            icon: Icons.savings_rounded,
            iconBg: palette.rewardSoft,
            iconFg: palette.reward,
            title: 'Poin saya',
            subtitle: 'Dipakai untuk memotong pembayaran',
            trailing: credit.hasValue
                ? AppFormat.rupiah(credit.value!)
                : credit.hasError
                ? '—'
                : '…',
            onTap: () => context.push('/profil/poin'),
          ),
          Divider(height: 1, indent: 66, color: scheme.outline),
          _NavRow(
            icon: Icons.receipt_long_rounded,
            iconBg: palette.brandSoft,
            iconFg: palette.brand,
            title: 'Riwayat transaksi',
            subtitle: 'Paket, sesi, langganan, kelas grup',
            onTap: () => context.push('/riwayat-transaksi'),
          ),
          Divider(height: 1, indent: 66, color: scheme.outline),
          _NavRow(
            icon: aktif ? Icons.menu_book_rounded : Icons.lock_outline_rounded,
            iconBg: aktif ? palette.successSoft : palette.challengeSoft,
            iconFg: aktif ? palette.success : palette.challenge,
            title: 'Langganan Bank Soal',
            subtitle: subDetail,
            onTap: () => context.push('/bank-soal'),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 20, color: iconFg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                trailing!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Biodata ───────────────────────────

class _BiodataCard extends StatelessWidget {
  const _BiodataCard({required this.profile, required this.isSiswa});

  final MyProfile profile;
  final bool isSiswa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = profile;
    final rows = <(IconData, String, String?)>[
      (Icons.person_outline_rounded, 'Nama lengkap', p.fullName),
      (Icons.phone_outlined, 'Nomor HP', p.phone),
      if (isSiswa) ...[
        (Icons.school_outlined, 'Jenjang', p.jenjang),
        (Icons.apartment_rounded, 'Sekolah', p.school),
        (
          Icons.cake_outlined,
          'Tanggal lahir',
          p.birthDate == null ? null : AppFormat.dateLong(p.birthDate!),
        ),
        (
          Icons.family_restroom_rounded,
          'Kontak darurat',
          [
            p.emergencyContactName,
            p.emergencyContactPhone,
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        ),
      ],
    ];
    final missing = rows.where((r) => (r.$3 ?? '').isEmpty).length;

    return _Box(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 46, color: scheme.outline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(rows[i].$1, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$2, style: theme.textTheme.labelSmall),
                        const SizedBox(height: 1),
                        Text(
                          (rows[i].$3 ?? '').isEmpty
                              ? 'Belum diisi'
                              : rows[i].$3!,
                          style: (rows[i].$3 ?? '').isEmpty
                              ? theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                )
                              : theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (missing > 0) ...[
            Divider(height: 1, color: scheme.outline),
            InkWell(
              onTap: () => context.push('/profil/edit'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: context.palette.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Lengkapi $missing data yang belum diisi',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Keamanan ───────────────────────────

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    return _Box(
      child: Column(
        children: [
          _NavRow(
            icon: Icons.alternate_email_rounded,
            iconBg: scheme.surfaceContainerHigh,
            iconFg: scheme.onSurfaceVariant,
            title: 'Email',
            subtitle: '${email ?? '-'} · dipakai untuk masuk',
            onTap: null,
          ),
          Divider(height: 1, indent: 66, color: scheme.outline),
          _NavRow(
            icon: Icons.lock_reset_rounded,
            iconBg: palette.brandSoft,
            iconFg: palette.brand,
            title: 'Ubah password',
            subtitle: 'Disarankan diganti berkala',
            onTap: () => context.push('/profil/password'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Pengaturan ───────────────────────────

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    ref.watch(themeModeProvider);
    final dark = ref.read(themeModeProvider.notifier).isDark(context);
    void soon() => ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Segera hadir.')));

    return _Box(
      child: Column(
        children: [
          SwitchListTile(
            value: dark,
            onChanged: (_) =>
                ref.read(themeModeProvider.notifier).toggle(context),
            secondary: Icon(
              Icons.dark_mode_outlined,
              color: scheme.onSurfaceVariant,
            ),
            title: const Text('Tema gelap'),
          ),
          Divider(height: 1, indent: 56, color: scheme.outline),
          ListTile(
            onTap: soon,
            leading: Icon(
              Icons.help_outline_rounded,
              color: scheme.onSurfaceVariant,
            ),
            title: const Text('Bantuan & FAQ'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          Divider(height: 1, indent: 56, color: scheme.outline),
          ListTile(
            onTap: soon,
            leading: Icon(
              Icons.shield_outlined,
              color: scheme.onSurfaceVariant,
            ),
            title: const Text('Kebijakan privasi'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return OutlinedButton.icon(
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Keluar dari akun?'),
            content: const Text(
              'Kamu perlu masuk lagi untuk memakai aplikasi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await ref.read(authControllerProvider.notifier).signOut();
        }
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: palette.danger,
        side: BorderSide(color: palette.danger.withValues(alpha: 0.35)),
        backgroundColor: palette.dangerSoft,
      ),
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('Keluar'),
    );
  }
}
