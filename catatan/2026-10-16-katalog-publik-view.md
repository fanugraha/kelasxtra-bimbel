# Katalog Publik Tutor — VIEW tanpa kolom bank

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

Fase 1/2, 16 Okt 2026. Policy lama `tutors: baca tutor aktif` membuka **seluruh kolom**
tutor aktif ke publik — termasuk `bank_name`, `bank_account_number`, `bank_account_holder`,
`invite_token`, `suspend_reason`. Harus ditutup sebelum katalog mobile dipakai.

## Keputusan atau temuan

- Migrasi `supabase/migrations/20261015000010_tutor_catalog_view.sql` (sudah diterapkan
  ke cloud `xbsiapwmhfcdenyeufhl`):
  - VIEW `public.tutor_catalog`: `id, full_name, bio, education, photo_url, rating_avg,
    activated_at, created_at`, `where status='aktif'`.
  - `grant select` ke `anon, authenticated`.
  - `drop policy "tutors: baca tutor aktif"`.
- **View definer (security_invoker=false) disengaja.** View dimiliki `postgres` (pemilik
  tabel) → menembus RLS, jadi anon cukup grant pada view. Kalau `security_invoker=true`,
  RLS tabel berlaku untuk pemanggil → siswa tak punya policy baca tutor lain → katalog
  kosong. Definisi: RLS hanya menyembunyikan baris, bukan kolom; jadi kolom bank tak bisa
  disembunyikan lewat policy — harus lewat view.
- **Linter `security_definer_view` (ERROR) = known/intentional.** Supabase menandai view
  definer sebagai bahaya; di sini aman karena view hanya memilih baris `aktif` + kolom aman.
  Jangan tambah kolom sensitif ke view.
- Akses tabel langsung `tutors` setelah ini: tutor (baris sendiri, termasuk bank) + admin.
  Anon/`authenticated` lain → tak ada policy SELECT → 0 baris.
- Verifikasi: view 8 kolom (tanpa bank), policy tersisa 3, `anon` bisa `select` view.

## Alasan

- View lebih baik dari kolom-level GRANT: `authenticated` dipakai bersama siswa+tutor+admin;
  grant kolom tak bisa membedakan per-baris (tutor butuh bank sendiri, siswa tidak).

## Langkah berikutnya

- Mobile siswa: baca katalog dari `tutor_catalog`, filter mapel/jenjang via `tutor_subjects`.
- Lanjut Fase 2: Edge Function `create-snap` + `midtrans-webhook` (butuh Midtrans Sandbox).

## Tautan terkait

- [[2026-10-15-fase-2-katalog-booking]]
- [[2026-10-15-keputusan-teknis-kelasxtra]]
