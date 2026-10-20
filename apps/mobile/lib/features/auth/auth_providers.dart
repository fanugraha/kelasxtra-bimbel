import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final myProfileProvider = FutureProvider<MyProfile>((ref) {
  ref.watch(authStateProvider);
  return ref.read(authRepositoryProvider).fetchMyProfile();
});

/// Riwayat poin siswa (masuk & terpakai).
final creditHistoryProvider = FutureProvider<List<CreditEntry>>((ref) {
  ref.watch(authStateProvider);
  return ref.read(authRepositoryProvider).fetchCreditHistory();
});

/// Sesi auth berubah (login/logout). Dipakai router untuk redirect.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => supabase.auth.onAuthStateChange,
);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendly(e);
    }
  }

  Future<String?> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String jenjang,
    required String emergencyContactName,
    required String emergencyContactPhone,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signUpStudent(
        email: email,
        password: password,
        fullName: fullName,
      );
      // Bila konfirmasi email nonaktif, sesi langsung ada -> isi profil siswa.
      if (supabase.auth.currentSession != null) {
        await repo.completeStudentProfile(
          jenjang: jenjang,
          fullName: fullName,
          emergencyContactName: emergencyContactName,
          emergencyContactPhone: emergencyContactPhone,
          guardianConsent: true,
        );
      }
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendly(e);
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  String _friendly(Object e) =>
      e is AuthException ? e.message : 'Terjadi kesalahan. Coba lagi.';
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
