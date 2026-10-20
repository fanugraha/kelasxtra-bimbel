import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_error_text.dart';
import '../../core/widgets/screen_head.dart';
import 'auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _ecName = TextEditingController();
  final _ecPhone = TextEditingController();
  String _jenjang = 'SMP';
  bool _consent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _ecName, _ecPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      setState(() => _error = 'Wajib mencentang pernyataan izin mandiri.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await ref
        .read(authControllerProvider.notifier)
        .signUpStudent(
          email: _email.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
          jenjang: _jenjang,
          emergencyContactName: _ecName.text.trim(),
          emergencyContactPhone: _ecPhone.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ScreenHead(
                  showBack: true,
                  title: 'Daftar Siswa',
                  subtitle:
                      'Data dipakai untuk keselamatan dan penjadwalan sesi.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nama lengkap'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _jenjang,
                  decoration: const InputDecoration(labelText: 'Jenjang'),
                  items: [
                    for (final j in AppConstants.jenjang)
                      DropdownMenuItem(value: j, child: Text(j)),
                  ],
                  onChanged: (v) => setState(() => _jenjang = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email tidak valid'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata sandi (min 6)',
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ecName,
                  decoration: const InputDecoration(
                    labelText: 'Nama kontak darurat',
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ecPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'No. HP kontak darurat',
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Saya menyatakan mendaftar atas izin mandiri dan data ini benar.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                AppErrorText(_error),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Daftar',
                  loading: _loading,
                  onPressed: _submit,
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sudah punya akun? Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
