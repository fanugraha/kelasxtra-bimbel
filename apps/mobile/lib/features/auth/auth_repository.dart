import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// Profil gabungan `profiles` + `students` (kolom siswa null untuk tutor).
typedef MyProfile = ({
  String? role,
  String? fullName,
  String? email,
  String? phone,
  String? jenjang,
  String? school,
  String? emergencyContactName,
  String? emergencyContactPhone,
  String? avatarUrl,
  DateTime? birthDate,
});

/// Satu baris riwayat poin siswa (+ masuk, − terpakai).
class CreditEntry {
  const CreditEntry({
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.note,
  });

  final int amount;
  final String reason;
  final DateTime createdAt;
  final String? note;

  /// Label alasan yang dimengerti siswa.
  String get label => switch (reason) {
    'tutor_no_show' => 'Kompensasi tutor tidak hadir',
    'complaint' => 'Kompensasi komplain',
    'package_cancel' => 'Pembatalan paket',
    'group_cancel' => 'Pembatalan kelas grup',
    'checkout' => 'Dipakai untuk pembayaran',
    'manual' => 'Poin dari admin',
    _ => reason,
  };

  factory CreditEntry.fromMap(Map<String, dynamic> m) => CreditEntry(
    amount: (m['amount'] as num).toInt(),
    reason: (m['reason'] ?? '') as String,
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    note: m['note'] as String?,
  );
}

class AuthRepository {
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Registrasi siswa. `profiles` dibuat otomatis oleh trigger DB.
  /// Data siswa (jenjang, kontak darurat, izin) diisi setelah akun terbentuk.
  Future<AuthResponse> signUpStudent({
    required String email,
    required String password,
    required String fullName,
  }) {
    return supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> completeStudentProfile({
    required String jenjang,
    required String fullName,
    required String emergencyContactName,
    required String emergencyContactPhone,
    bool guardianConsent = false,
  }) {
    final uid = supabase.auth.currentUser!.id;
    return supabase.from('students').insert({
      'id': uid,
      'jenjang': jenjang,
      'full_name': fullName,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'guardian_consent': guardianConsent,
      'guardian_consent_at': guardianConsent
          ? DateTime.now().toUtc().toIso8601String()
          : null,
    });
  }

  Future<MyProfile> fetchMyProfile() async {
    final uid = supabase.auth.currentUser!.id;
    final p = await supabase
        .from('profiles')
        .select('role, full_name, email, phone, avatar_url')
        .eq('id', uid)
        .single();
    final s = await supabase
        .from('students')
        .select(
          'jenjang, school, birth_date, emergency_contact_name, '
          'emergency_contact_phone',
        )
        .eq('id', uid)
        .maybeSingle();

    return (
      role: p['role'] as String?,
      fullName: p['full_name'] as String?,
      email: p['email'] as String?,
      phone: p['phone'] as String?,
      jenjang: s?['jenjang'] as String?,
      school: s?['school'] as String?,
      emergencyContactName: s?['emergency_contact_name'] as String?,
      emergencyContactPhone: s?['emergency_contact_phone'] as String?,
      avatarUrl: p['avatar_url'] as String?,
      birthDate: s?['birth_date'] == null
          ? null
          : DateTime.parse(s!['birth_date'] as String),
    );
  }

  /// Simpan biodata. `profiles` (nama, HP) untuk semua peran; kolom siswa
  /// hanya bila [isSiswa]. Email & peran sengaja tidak bisa diubah di sini.
  Future<void> updateBiodata({
    required bool isSiswa,
    required String fullName,
    String? phone,
    String? jenjang,
    String? school,
    DateTime? birthDate,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    String? clean(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    await supabase
        .from('profiles')
        .update({'full_name': fullName.trim(), 'phone': clean(phone)})
        .eq('id', uid);
    if (!isSiswa) return;
    await supabase
        .from('students')
        .update({
          'full_name': fullName.trim(),
          'jenjang': ?jenjang,
          'school': clean(school),
          'birth_date': birthDate == null
              ? null
              : '${birthDate.year.toString().padLeft(4, '0')}-'
                    '${birthDate.month.toString().padLeft(2, '0')}-'
                    '${birthDate.day.toString().padLeft(2, '0')}',
          'emergency_contact_name': clean(emergencyContactName),
          'emergency_contact_phone': clean(emergencyContactPhone),
        })
        .eq('id', uid);
  }

  /// Unggah foto profil ke bucket publik `avatars/{uid}/…` lalu simpan URL-nya.
  /// Nama berkas memakai waktu agar cache gambar lama tidak terpakai.
  Future<String> uploadAvatar(Uint8List bytes, {String ext = 'jpg'}) async {
    final uid = supabase.auth.currentUser!.id;
    final path = '$uid/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            upsert: true,
          ),
        );
    final url = supabase.storage.from('avatars').getPublicUrl(path);
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', uid);
    return url;
  }

  /// Ganti password. Password lama diverifikasi dulu (masuk ulang) supaya
  /// HP yang tertinggal dalam keadaan login tidak bisa dipakai mengganti.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) throw const AuthException('Akun tidak ditemukan.');
    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException {
      throw const AuthException('Password lama salah.');
    }
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Riwayat poin siswa, terbaru dulu.
  Future<List<CreditEntry>> fetchCreditHistory() async {
    final rows = await supabase
        .from('student_credits')
        .select('amount, reason, note, created_at')
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final r in rows) CreditEntry.fromMap(r)];
  }

  Future<void> signOut() => supabase.auth.signOut();
}
