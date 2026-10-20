import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_error_text.dart';
import 'auth_providers.dart';

/// Layar masuk ala aplikasi super (mis. Gojek): hero berwarna brand di atas
/// dengan karusel manfaat yang bergeser sendiri, lalu lembar putih membulat
/// berisi formulir di bawah. Saat keyboard muncul, karusel diringkas supaya
/// kolom isian tetap terlihat.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Tombol "Masuk" baru aktif setelah kedua kolom terisi.
    _email.addListener(_refresh);
    _password.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _filled =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_filled || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await ref
        .read(authControllerProvider.notifier)
        .signIn(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final flavor = ref.watch(appFlavorProvider);
    final theme = Theme.of(context);
    final tutor = flavor == AppFlavor.tutor;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Gradasi hero: mode gelap diredupkan 20% ke hitam. Teks putih di titik
    // terterang (#007B9E) = 4.85:1 (terang) / 6.89:1 (gelap).
    final heroGradient = theme.brightness == Brightness.dark
        ? LinearGradient(
            begin: AppColors.gradient.begin,
            end: AppColors.gradient.end,
            colors: [
              for (final c in AppColors.gradient.colors)
                Color.lerp(c, Colors.black, 0.2)!,
            ],
          )
        : AppColors.gradient;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: heroGradient),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    _Hero(tutor: tutor, compact: keyboardUp),
                    _FormSheet(
                      tutor: tutor,
                      email: _email,
                      password: _password,
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      error: _error,
                      loading: _loading,
                      onSubmit: _filled ? _submit : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero ────────────────────────────────────────────────────────────────────

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _siswaSlides = [
  _Slide(
    Icons.event_available_rounded,
    'Les privat sesuai jadwalmu',
    'Pilih tutor dan jam yang pas, pesan langsung dari HP.',
  ),
  _Slide(
    Icons.quiz_rounded,
    'Latihan soal tiap mapel',
    'Bank soal dan tryout dengan pembahasan, bisa dicicil kapan saja.',
  ),
  _Slide(
    Icons.insights_rounded,
    'Pantau perkembanganmu',
    'Lihat mapel terkuat dan bagian yang masih perlu diasah.',
  ),
];

const _tutorSlides = [
  _Slide(
    Icons.calendar_month_rounded,
    'Atur jadwal mengajar',
    'Semua sesi siswa tersusun rapi dalam satu tempat.',
  ),
  _Slide(
    Icons.fact_check_rounded,
    'Absensi tercatat otomatis',
    'Tandai kehadiran dan catatan sesi dalam beberapa ketukan.',
  ),
  _Slide(
    Icons.account_balance_wallet_rounded,
    'Penghasilan transparan',
    'Cek slip penghasilan tiap periode kapan pun kamu perlu.',
  ),
];

class _Hero extends StatelessWidget {
  const _Hero({required this.tutor, required this.compact});

  final bool tutor;

  /// Keyboard terbuka → hanya baris logo, karusel disembunyikan.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        // Lingkaran dekoratif lembut di latar hero.
        Positioned(right: -60, top: -40, child: _Blob(size: 220)),
        Positioned(left: -50, bottom: 10, child: _Blob(size: 140)),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      'K',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Kelasxtra',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  // Putih penuh: putih 70% hanya 3.17:1 di #007B9E.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      tutor ? 'Ruang tutor' : 'Ruang siswa',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: compact
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _SlideCarousel(
                          slides: tutor ? _tutorSlides : _siswaSlides,
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

class _Blob extends StatelessWidget {
  const _Blob({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }
}

/// Karusel manfaat. Bergeser otomatis tiap [_interval], jeda dihitung ulang
/// saat pengguna menggeser sendiri, dan diam bila animasi dimatikan di HP.
class _SlideCarousel extends StatefulWidget {
  const _SlideCarousel({required this.slides});
  final List<_Slide> slides;

  @override
  State<_SlideCarousel> createState() => _SlideCarouselState();
}

class _SlideCarouselState extends State<_SlideCarousel> {
  final _controller = PageController();
  var _page = 0;
  Timer? _timer;

  static const _interval = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _advance());
  }

  void _advance() {
    if (!mounted || !_controller.hasClients) return;
    if (!TickerMode.of(context)) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _controller.animateToPage(
      (_page + 1) % widget.slides.length,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 228,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (n) {
              if (n.dragDetails != null) _restart();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final s = widget.slides[i];
                return Column(
                  children: [
                    _Illustration(icon: s.icon),
                    const SizedBox(height: 18),
                    Text(
                      s.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        s.body,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: i == _page ? 1 : 0.4,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Ilustrasi ringan dari ikon: cincin bertumpuk + dua "kilau" kecil.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const Positioned(
            right: 4,
            top: 10,
            child: Icon(Icons.auto_awesome, size: 20, color: AppColors.star),
          ),
          Positioned(
            left: 6,
            bottom: 14,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentAlt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formulir ────────────────────────────────────────────────────────────────

class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.tutor,
    required this.email,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.error,
    required this.loading,
    required this.onSubmit,
  });

  final bool tutor;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final String? error;
  final bool loading;

  /// Null bila kolom belum lengkap → tombol nonaktif.
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    // Expanded: lembar mengisi sisa layar sampai bawah, tanpa celah gradien.
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.sheet,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          26,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tutor ? 'Masuk sebagai tutor' : 'Masuk ke akunmu',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tutor
                    ? 'Kelola jadwal, absensi, dan slip penghasilanmu.'
                    : 'Selamat datang lagi! Yuk lanjutkan belajarmu.',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'nama@kelasxtra.id',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => onSubmit?.call(),
                decoration: InputDecoration(
                  labelText: 'Kata sandi',
                  hintText: 'Minimal 8 karakter',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: obscure
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              AppErrorText(error),
              const SizedBox(height: 20),
              AppButton(label: 'Masuk', loading: loading, onPressed: onSubmit),
              if (!tutor) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum punya akun?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: muted,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Daftar sekarang'),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 14, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    'Data akunmu terenkripsi dan aman',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
