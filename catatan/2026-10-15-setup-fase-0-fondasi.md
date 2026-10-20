# Setup Fase 0 — Fondasi

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

Sesi 15 Okt 2026: setup awal proyek dari brief v2.0. Folder kerja
`/Users/mac/Documents/Kelasxtra-Bimbel` (sebelumnya kosong).

## Keputusan atau temuan

Yang dibuat:

- **Monorepo**: `apps/mobile` (Flutter), `apps/dashboard` (React+TS+Vite), `supabase/`, `docs/`, `catatan/`.
- **Migrasi Supabase** (`supabase/migrations/`):
  - `...0001_extensions` — pgcrypto, pg_cron, pg_net, helper `set_updated_at`.
  - `...0002_profiles` — tabel + `is_admin()`, trigger `handle_new_user`, RLS.
  - `...0003_students` — kontak darurat + izin mandiri + RLS.
  - `...0004_tutors` — status diundang/aktif/suspend, data bank, token undangan + RLS.
  - `...0005_storage` — buckets `avatars`/`question-assets`/`tutor-documents` + policy.
  - `...0006_master_data` — `levels`, `subjects`, `topics`, `price_matrix`.
- **`supabase/seed.sql`** — jenjang, mapel, topik, price matrix (harga **placeholder**).
- **Mobile**: core (env, supabase client, theme, router, flavor), fitur auth (login + registrasi siswa), home. `flutter analyze` bersih.
- **Dashboard**: supabase client, auth context, layout sidebar, login, registry 9 modul (placeholder), guard route. `npm run build` lulus.
- **CI** GitHub Actions (mobile analyze/test; dashboard lint/build), `.gitignore`, README.

## Alasan

- Fase 0 dipilih dulu agar fondasi auth + RLS + struktur terbukti sebelum fitur.
- Tabel master data (`levels`/`subjects`/`topics`/`price_matrix`) dibuat sekarang karena `seed.sql` membutuhkannya dan risikonya rendah.

## Langkah berikutnya

- Uji RLS akses silang (siswa A tak bisa baca data siswa B).
- Buat akun admin pertama (via SQL/service role) — belum ada alur di app.
- Fase 1: undangan tutor → aktivasi → profil tayang.

## Update sesi (15 Okt 2026, lanjutan)

- Docker Desktop sempat error I/O karena disk hampir habis (sisa 7 GiB). Data VM
  Docker dihapus (~9 GiB bebas). **Keputusan: tinggalkan Supabase lokal, pakai Supabase Cloud.**
- Project cloud: ref `xbsiapwmhfcdenyeufhl` (region Singapore).
- `supabase link` + `db push` → 6 migrasi terkirim. `db push --include-seed` → seed masuk.
  Verifikasi REST: levels 3, subjects 7, topics 10, price_matrix 24.
- Kredensial klien (publishable key) di `apps/dashboard/.env` (gitignored) + dart-define mobile.
- **Catatan penting**: secret key sempat salah taruh di `.env.example` (file yang ikut commit).
  Belum ada commit jadi belum bocor, tapi perlu di-rotate di dashboard.
- TODO: pengujian RLS & pembuatan admin pertama belum dilakukan.

## Update sesi 2 (15 Okt 2026) — verifikasi cloud + RLS

- **Dashboard** jalan lokal (`npm run dev`, localhost:5173), env cloud tersuntik benar.
- **RLS diuji & lolos** (uji silang siswa A vs B lewat project cloud):
  - A baca `students` → hanya barisnya sendiri.
  - A paksa baca baris B → kosong.
  - A lihat `profiles` → hanya dirinya.
  - A coba update/delete baris B → 0 baris terpengaruh, data B utuh.
  - Anon (tanpa login) → semua tabel user `[]`.
  - Akun uji dihapus setelah selesai.
- Cara uji tanpa login email: admin `generate_link` (magiclink) → `auth/v1/verify` → ambil access_token. Berguna karena "Confirm email" cloud menyala.
- **Perhatian**: saat mencoba mematikan "Confirm email", yang termatikan justru toggle
  **Enable email provider** (login email jadi mati). Harus dinyalakan lagi: Dashboard →
  Authentication → Sign In / Providers → Email → Enable email provider = ON.
- Secret key lama masih dipakai untuk uji server; **belum di-rotate**. Perlu rotate.
- **Belum**: akun admin pertama; jalankan ulang `flutter analyze` setelah kredensial mobile.

## Update sesi 3 (15 Okt 2026) — akun admin pertama via MCP supabase

- MCP supabase sudah terhubung (project `kelasxtra-bimbel`, ref `xbsiapwmhfcdenyeufhl`).
- 6 migrasi terverifikasi terpasang di cloud.
- **Akun admin pertama dibuat** langsung lewat SQL (MCP `execute_sql`), bukan UI.
  Uji login lewat `auth/v1/token` → berhasil.
- **Model admin**: super admin = `role='admin'` + `admin_role` **NULL**.
  `admin_role` hanya untuk pembatasan sub-peran: `verifikator | finance | konten | cs`.
  `admin_role='super_admin'` DITOLAK constraint — jangan pakai nilai itu.
- **Pelajaran buat user auth via SQL**: `auth.identities.email` adalah *generated column*
  (jangan diisi); butuh baris di `auth.identities` + `auth.users` agar login jalan.
- `flutter analyze` mobile bersih.
- **Sisa Fase 0**: rotate secret key lama — selesai 20 Okt 2026: legacy keys dimatikan dan legacy JWT signing key dicabut.
- **Aturan kerja**: JANGAN `flutter run` / pasang emulator. Uji mobile di HP Android
  milik pemilik. `flutter analyze` (cek statis) tetap boleh.

## Tautan terkait

- [[2026-10-15-keputusan-teknis-kelasxtra]]
- [[2026-10-15-tooling-mcp-library]]
- [[2026-10-15-konteks-proyek-kelasxtra-bimbel]]
