import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_head.dart';
import 'auth_providers.dart';

/// Kekuatan password 0–3 (lemah, sedang, kuat, sangat kuat).
int passwordStrength(String p) {
  var score = 0;
  if (p.length >= 8) score++;
  if (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) score++;
  if (p.length >= 12 || RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
  return p.length < 8 ? 0 : score;
}

/// Ubah password: password lama wajib (diverifikasi server), password baru
/// min. 8 karakter dengan indikator kekuatan, lalu konfirmasi.
class UbahPasswordScreen extends ConsumerStatefulWidget {
  const UbahPasswordScreen({super.key});

  @override
  ConsumerState<UbahPasswordScreen> createState() => _UbahPasswordState();
}

class _UbahPasswordState extends ConsumerState<UbahPasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  var _show = false;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diubah.')),
      );
      context.pop();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    suffixIcon: IconButton(
      tooltip: _show ? 'Sembunyikan' : 'Tampilkan',
      onPressed: () => setState(() => _show = !_show),
      icon: Icon(
        _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final strength = passwordStrength(_new.text);
    final (label, color) = switch (strength) {
      0 => ('Terlalu pendek', palette.danger),
      1 => ('Lemah', palette.warning),
      2 => ('Cukup kuat', palette.info),
      _ => ('Kuat', palette.success),
    };

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _key,
          child: ListView(
            padding: screenPadding,
            children: [
              const ScreenHead(
                showBack: true,
                title: 'Ubah password',
                subtitle: 'Demi keamanan, masukkan password lamamu dulu.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg + 2),
                  border: Border.all(color: scheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _current,
                      obscureText: !_show,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.next,
                      decoration: _decor('Password lama'),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Isi password lama' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _new,
                      obscureText: !_show,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: _decor('Password baru'),
                      validator: (v) {
                        final s = v ?? '';
                        if (s.length < 8) return 'Minimal 8 karakter';
                        if (s == _current.text) {
                          return 'Harus berbeda dari password lama';
                        }
                        return null;
                      },
                    ),
                    if (_new.text.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: i < strength
                                      ? color
                                      : scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _confirm,
                      obscureText: !_show,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: _decor('Ulangi password baru'),
                      validator: (v) =>
                          v != _new.text ? 'Password tidak sama' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tips: gabungkan huruf, angka, dan simbol. Jangan pakai '
                'tanggal lahir atau nama.',
                style: theme.textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: palette.dangerSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: palette.danger),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Simpan password baru'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
