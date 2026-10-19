import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/providers.dart';
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('K',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kelasxtra',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontSize: 20)),
                      Text(tutor ? 'Ruang tutor' : 'Ruang siswa',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
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
