import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_error_text.dart';
import '../../core/widgets/screen_head.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: heroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'K',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kelasxtra',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          // Putih penuh: putih 70% hanya 3.17:1 di #007B9E.
                          Text(
                            tutor ? 'Ruang tutor' : 'Ruang siswa',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              ScreenHead(
                eyebrow: 'Selamat datang',
                title: tutor ? 'Masuk Tutor' : 'Masuk Siswa',
                subtitle: tutor
                    ? 'Kelola jadwal, absensi, dan slip penghasilanmu.'
                    : 'Lanjutkan belajar, cek jadwal, dan kerjakan bank soal.',
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'nama@kelasxtra.id',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Kata sandi',
                  hintText: 'Minimal 8 karakter',
                ),
              ),
              AppErrorText(_error),
              const SizedBox(height: 18),
              AppButton(label: 'Masuk', loading: _loading, onPressed: _submit),
              if (flavor == AppFlavor.siswa) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Belum punya akun? Daftar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
