import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Inisialisasi Supabase sekali di awal aplikasi.
/// Anon key aman di client; RLS deny-by-default melindungi data.
/// Service role key TIDAK PERNAH dipakai di client (hanya di Edge Functions).
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // Kunci publik client (anon / publishable). Aman di client; RLS yang melindungi.
    publishableKey: Env.supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
