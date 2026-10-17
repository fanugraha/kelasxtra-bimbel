import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// Profil gabungan `profiles` + `students` (kolom siswa null untuk tutor).
typedef MyProfile = ({
  String? fullName,
  String? email,
  String? phone,
  String? jenjang,
  String? school,
  String? emergencyContactName,
  String? emergencyContactPhone,
});

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
      data: {'role': 'student', 'full_name': fullName},
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
      'guardian_consent_at': guardianConsent ? DateTime.now().toUtc().toIso8601String() : null,
    });
  }

  Future<MyProfile> fetchMyProfile() async {
    final uid = supabase.auth.currentUser!.id;
    final p = await supabase
        .from('profiles')
        .select('full_name, email, phone')
        .eq('id', uid)
        .single();
    final s = await supabase
        .from('students')
        .select('jenjang, school, emergency_contact_name, emergency_contact_phone')
        .eq('id', uid)
        .maybeSingle();

    return (
      fullName: p['full_name'] as String?,
      email: p['email'] as String?,
      phone: p['phone'] as String?,
      jenjang: s?['jenjang'] as String?,
      school: s?['school'] as String?,
      emergencyContactName: s?['emergency_contact_name'] as String?,
      emergencyContactPhone: s?['emergency_contact_phone'] as String?,
    );
  }

  Future<void> signOut() => supabase.auth.signOut();
}
