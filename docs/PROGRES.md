# Progres Implementasi

Status per fase. Diperbarui setiap sesi. Acuan: [brief-implementasi-v2.0.md](brief-implementasi-v2.0.md).
Rencana lengkap: [RENCANA-DEV.md](RENCANA-DEV.md).

## Legenda
✅ selesai · 🟡 sebagian · ⬜ belum

## Ringkasan

| Fase | Nama | Status |
|---|---|---|
| 0 | Fondasi | ✅ |
| 1 | Akun & Profil | 🟡 |
| 2 | Katalog & Booking Privat + Pembayaran | 🟡 |
| 3 | Paket Sesi | ⬜ |
| 4 | Kelas Grup | ⬜ |
| 5 | Bank Soal + Analisis | ⬜ |
| 6 | Absensi, Reschedule, Komplain, Pesan | ⬜ |
| 7 | Payroll Bulanan | ⬜ |
| 8 | Dashboard Management & Operasional | ⬜ |
| 9 | Notifikasi & Hardening | ⬜ |

## Fase 0 — Fondasi (✅)

- [x] Monorepo: `apps/mobile`, `apps/dashboard`, `supabase/`, `docs/`, `catatan/`
- [x] Supabase migration: `profiles`, `students`, `tutors` (+ helper `is_admin`)
- [x] RLS deny-by-default untuk tabel Fase 0
- [x] Trigger `handle_new_user` (auto-buat profil saat signup)
- [x] Storage buckets: `avatars`, `question-assets`, `tutor-documents`
- [x] Master data: `levels`, `subjects`, `topics`, `price_matrix` + `seed.sql`
- [x] Flutter skeleton: 2 flavor (`main_siswa.dart` / `main_tutor.dart`), Riverpod, go_router, auth
- [x] Dashboard skeleton: React+TS+Vite, Supabase client, auth guard, registry modul
- [x] CI (lint + build) + `.gitignore` + README
- [x] MCP global dipasang: supabase, context7, playwright, github (butuh restart opencode)
- [x] Skill proyek `.opencode/skills/kelasxtra-bimbel/SKILL.md`
- [x] Library terpasang: mobile (`intl`, `geolocator`, `firebase_core`, `firebase_messaging`, `image_picker`), dashboard (`katex`, `react-katex`)
- [x] RLS diuji tolak akses silang user (cloud, 15 Okt 2026) — lihat catatan
- [x] Akun admin pertama dibuat (`admin@kelasxtra.id`, `role=admin`, `admin_role=null`; via MCP supabase 15 Okt 2026). Password awal harus diganti.
- [x] `flutter analyze` bersih setelah kredensial mobile (15 Okt 2026)
- [ ] **Utang keamanan**: rotate secret key lama (sempat salah taruh di `.env.example`) — manual di dashboard
- [ ] Validasi `supabase db reset` lokal (opsional; cloud sudah jadi acuan uji)

## Fase 1 — Akun & Profil (🟡)

- [x] Migrasi `audit_logs` (+ RLS: admin baca; insert hanya service role)
- [x] Edge Function `invite-tutor` (admin buat akun + token 7 hari; kirim email bila Resend aktif)
- [x] Edge Function `activate-tutor` (publik: validasi token → set password → isi profil/bank → aktif)
- [x] Edge Function `manage-tutor` (suspend/reactivate/resend undangan + audit log + ban akun saat suspend)
- [x] Dashboard modul **Tutor & Undangan** (buat, kirim ulang, suspend/reaktivasi)
- [x] Halaman aktivasi **web** `/activate?token=...` (dipilih dibanding deep link mobile — lihat catatan)
- [x] Registrasi siswa mandiri + checkbox izin + kontak darurat (dari Fase 0, tetap berlaku)
- [x] Uji end-to-end: invite → aktivasi web → `tutors.status='aktif'` (Playwright + SQL)
- [ ] **Email otomatis** undangan via Resend — **ditunda**. Keputusan: admin salin link & kirim manual (WhatsApp). Kode `invite-tutor` sudah siap kirim email; tinggal selesaikan DNS domain `kelasxtra.my.id` di Cloudflare lalu set `RESEND_API_KEY` (sudah diset, tapi domain belum Verified).
- [x] Katalog publik tutor: VIEW `public.tutor_catalog` (tanpa kolom bank/token) + cabut policy `tutors: baca tutor aktif` (migrasi `...00010_tutor_catalog_view`, 16 Okt 2026)

## Fase 2 — Katalog & Booking Privat (🟡)

- [x] Migrasi `tutor_subjects`, `tutor_availability`, `vouchers`, `voucher_redemptions`, `bookings`, `payments` + RLS
  - `bookings`: `tutor_share`/`platform_share`/`amount_due` = **generated columns** (integer, `floor(price*75/100)`)
- [x] RPC `set_price` (ubah harga + versi lama jadi riwayat + tulis `audit_logs`)
- [x] Dashboard modul **Price Matrix** (edit harga inline + tampilkan riwayat)
- [x] Dashboard modul **Voucher** (CRUD, aktif/nonaktif, kuota)
- [x] VIEW `public.tutor_catalog` — katalog publik tutor tanpa kolom bank (bypass RLS disengaja; linter `security_definer_view` = known/intentional)
- [ ] Edge Function `create-snap` (buat booking pending + Midtrans Snap; butuh Midtrans Sandbox keys)
- [ ] Edge Function `midtrans-webhook` (idempoten by `order_id`; verifikasi signature SHA512)
- [ ] Mobile siswa: katalog (filter mapel/jenjang/mode/harga), profil tutor, pilih slot → ringkasan → voucher → Snap → status
- [ ] Slot lock 30 menit (`lock_expires_at`); auto-accept; alamat terbuka pasca-bayar
- [ ] Prasyarat: akun **Midtrans Sandbox** (Server Key, Client Key) → set secret Edge Function

## Langkah berikutnya

1. Set secret email: `supabase secrets set RESEND_API_KEY=... EMAIL_FROM="Kelasxtra <noreply@domainmu>" ACTIVATION_BASE_URL="https://<domain-dashboard>/activate"`.
2. Konfigurasi Supabase SMTP (Resend) untuk email auth siswa.
3. Mulai **Fase 2** (katalog + booking + Midtrans) — putuskan O7 (harga) & O8 (domain webhook) dulu.
