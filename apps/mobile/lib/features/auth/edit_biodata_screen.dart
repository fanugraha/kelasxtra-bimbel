import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/screen_head.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

/// Nomor HP Indonesia: 08…, 628…, atau +628… (spasi/strip diabaikan).
final _phoneRe = RegExp(r'^(\+62|62|0)8\d{7,12}$');

String? validatePhone(String? v, {bool required = false}) {
  final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
  if (s.isEmpty) return required ? 'Wajib diisi' : null;
  return _phoneRe.hasMatch(s) ? null : 'Format nomor HP belum benar (08…)';
}

/// Edit biodata: dikelompokkan per kartu (Data diri, Sekolah, Kontak
/// darurat). Tombol Simpan di bawah layar, aktif hanya bila ada perubahan;
/// keluar tanpa simpan meminta konfirmasi.
class EditBiodataScreen extends ConsumerWidget {
  const EditBiodataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: AsyncView<MyProfile>(
          value: ref.watch(myProfileProvider),
          errorTitle: 'Gagal memuat biodata',
          onRetry: () => ref.invalidate(myProfileProvider),
          builder: (p) => _Form(
            profile: p,
            isSiswa: ref.watch(appFlavorProvider) == AppFlavor.siswa,
          ),
        ),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.profile, required this.isSiswa});

  final MyProfile profile;
  final bool isSiswa;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _school = TextEditingController(text: widget.profile.school);
  late final _ecName = TextEditingController(
    text: widget.profile.emergencyContactName,
  );
  late final _ecPhone = TextEditingController(
    text: widget.profile.emergencyContactPhone,
  );
  late String? _jenjang = widget.profile.jenjang;
  late DateTime? _birth = widget.profile.birthDate;
  var _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _school, _ecName, _ecPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _dirty {
    final p = widget.profile;
    bool diff(TextEditingController c, String? v) =>
        c.text.trim() != (v ?? '').trim();
    return diff(_name, p.fullName) ||
        diff(_phone, p.phone) ||
        (widget.isSiswa &&
            (diff(_school, p.school) ||
                diff(_ecName, p.emergencyContactName) ||
                diff(_ecPhone, p.emergencyContactPhone) ||
                _jenjang != p.jenjang ||
                _birth != p.birthDate));
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 15),
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year - 5),
      helpText: 'Tanggal lahir',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _birth = picked);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateBiodata(
            isSiswa: widget.isSiswa,
            fullName: _name.text,
            phone: _phone.text,
            jenjang: _jenjang,
            school: _school.text,
            birthDate: _birth,
            emergencyContactName: _ecName.text,
            emergencyContactPhone: _ecPhone.text,
          );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Biodata tersimpan.')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: const Text('Perubahan biodata belum disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Buang'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Lanjut mengedit'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = widget.isSiswa;
    const gap = SizedBox(height: AppSpacing.md);

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context);
      },
      child: Form(
        key: _key,
        onChanged: () => setState(() {}),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: screenPadding,
                children: [
                  const ScreenHead(
                    showBack: true,
                    title: 'Edit biodata',
                    subtitle:
                        'Pastikan datamu benar supaya tutor & admin '
                        'mudah menghubungi.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Card(
                    icon: Icons.badge_outlined,
                    title: 'Data diri',
                    children: [
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nama lengkap',
                        ),
                        validator: (v) => (v ?? '').trim().length < 3
                            ? 'Isi nama lengkap (min. 3 huruf)'
                            : null,
                      ),
                      gap,
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nomor HP',
                          hintText: '08xxxxxxxxxx',
                        ),
                        validator: validatePhone,
                      ),
                      if (s) ...[
                        gap,
                        _BirthField(value: _birth, onTap: _pickBirth),
                      ],
                    ],
                  ),
                  if (s) ...[
                    gap,
                    _Card(
                      icon: Icons.school_outlined,
                      title: 'Sekolah',
                      children: [
                        Text('Jenjang', style: theme.textTheme.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        SegmentedButton<String>(
                          segments: [
                            for (final j in AppConstants.jenjang)
                              ButtonSegment(value: j, label: Text(j)),
                          ],
                          selected: {?_jenjang},
                          emptySelectionAllowed: true,
                          showSelectedIcon: false,
                          onSelectionChanged: (v) =>
                              setState(() => _jenjang = v.firstOrNull),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Jenjang menentukan soal & tutor yang disarankan.',
                          style: theme.textTheme.bodySmall,
                        ),
                        gap,
                        TextFormField(
                          controller: _school,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nama sekolah',
                            hintText: 'Contoh: SMAN 1 Bandung',
                          ),
                        ),
                      ],
                    ),
                    gap,
                    _Card(
                      icon: Icons.family_restroom_rounded,
                      title: 'Kontak darurat',
                      subtitle: 'Orang tua atau wali yang bisa dihubungi.',
                      children: [
                        TextFormField(
                          controller: _ecName,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nama orang tua/wali',
                          ),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
                        ),
                        gap,
                        TextFormField(
                          controller: _ecPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Nomor HP orang tua/wali',
                            hintText: '08xxxxxxxxxx',
                          ),
                          validator: (v) => validatePhone(v, required: true),
                        ),
                      ],
                    ),
                  ],
                  gap,
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Email dipakai untuk masuk dan tidak bisa diubah '
                          'di sini.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outline)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _dirty && !_saving ? _save : null,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Text(
                          _dirty ? 'Simpan perubahan' : 'Belum ada perubahan',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BirthField extends StatelessWidget {
  const _BirthField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tanggal lahir',
          suffixIcon: Icon(Icons.calendar_month_outlined),
        ),
        isEmpty: value == null,
        child: Text(value == null ? '' : AppFormat.dateLong(value!)),
      ),
    );
  }
}

/// Kartu kelompok isian: ikon + judul (+ keterangan) lalu isian.
class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              Icon(icon, size: 20, color: palette.brand),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}
