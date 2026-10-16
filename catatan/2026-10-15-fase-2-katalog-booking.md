# Fase 2 — Katalog & Booking Privat + Pembayaran

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

Sesi 15 Okt 2026. Fase 2 dimulai atas delegasi pemilik. Keputusan tertunda O7 & O8
diselesaikan lebih dulu.

## Keputusan atau temuan

- **O7 (harga)**: dibangun **UI Price Matrix**; pemilik isi harga asli lewat dashboard.
  Seed tetap placeholder. Tak perlu menunggu angka final untuk lanjut koding.
- **O8 (webhook)**: pakai **URL Edge Function Supabase**
  (`https://<ref>.supabase.co/functions/v1/midtrans-webhook`) — publik otomatis, tanpa domain.
- **Schema Fase 2** (migrasi `...0008_catalog_booking`): `tutor_subjects`,
  `tutor_availability`, `vouchers`, `voucher_redemptions`, `bookings`, `payments` + RLS deny-by-default.
  - `bookings.tutor_share`/`platform_share`/`amount_due` = **generated columns** → aturan
    integer 75/25 **dipaksa di DB**, tak bisa dilanggar dari kode.
  - `bookings` punya 11 status (lihat check constraint).
  - Insert/ubah booking lewat Edge Function (service role) agar harga/status tak dipalsukan.
- **RPC `set_price`** (`...0009_pricing_rpc`): ubah harga atomik → versi lama jadi `active=false`
  (jadi **riwayat**), tulis `audit_logs`. Dipakai modul Price Matrix lewat `supabase.rpc`.
- **Voucher** = CRUD client langsung (RLS admin); validasi & kunci kuota nanti di server
  (Edge Function) untuk race-safety.
- **Verifikasi**: `set_price` diuji (harga baru aktif, lama jadi riwayat, audit di stage),
  lalu dikembalikan agar seed bersih.

## Alasan

- RPC SECURITY DEFINER dipakai (bukan Edge Function) untuk ubah harga: lebih ringkas, tetap
  tulis audit, tak perlu HTTP round-trip.
- Harga snapshot + generated columns = jaminan aturan uang tak bocor ke float/salah hitung.

## Langkah berikutnya

- Edge Function `create-snap` + `midtrans-webhook` (butuh Midtrans Sandbox keys).
- Mobile siswa: katalog + booking + status.
- Sebelum deploy: set secret Midtrans (`MIDTRANS_SERVER_KEY`, `MIDTRANS_CLIENT_KEY`, `MIDTRANS_IS_SANDBOX`).

## Tautan terkait

- [[2026-10-15-fase-1-akun-profil]]
- [[2026-10-15-keputusan-teknis-kelasxtra]]
