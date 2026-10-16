---
name: kelasxtra-bimbel
description: Aturan kerja proyek Kelasxtra Bimbel (marketplace bimbel: langganan bank soal + paket sesi tutor, Flutter + Supabase + Midtrans). Gunakan SETIAP kali bekerja di repo ini — menulis migrasi Supabase/RLS, kode Flutter (apps/mobile), dashboard React (apps/dashboard), fitur booking/paket/pembayaran/payroll, atau saat menyentuh uang, harga, jadwal sesi. Front-load trigger: "bimbel", "Kelasxtra", "tutor", "booking", "paket sesi", "bank soal", "payroll", "Midtrans", "price_matrix".
---

# Proyek Kelasxtra Bimbel

Marketplace bimbel Jogja. Dua produk independen: **langganan bank soal** (Rp29.000/bln,
Midtrans recurring) dan **paket sesi bimbel** (privat & grup maks 5, Snap sekali bayar).

## Sumber kebenaran

Baca dulu sebelum mengubah apa pun:

- `docs/brief-implementasi-v2.0.md` — **acuan kerja utama**. Bila bentrok dengan
  `docs/prd-v1.0.md`, **brief v2.0 menang** (tutor diundang admin tanpa upload KTP;
  payroll bulanan, bukan dompet+tarik; ada voucher + kelas grup).
- `docs/arsitektur.md` — stack, state machine booking (11 status), alur bayar/payroll.
- `docs/erd.md` — tabel data + fase pembuatannya.
- `docs/PROGRES.md` — status per fase (perbarui tiap sesi).

## Aturan bisnis kritis — JANGAN DILANGGAR

1. Slot tutor **auto-accept** — tak ada tombol terima/tolak.
2. **Uang = integer rupiah.** `tutor_share = floor(harga × 75 / 100)`;
   `platform_share = harga − tutor_share`. Jangan pakai float.
3. **Snapshot harga** ke booking/paket saat transaksi. Perubahan `price_matrix`
   hanya untuk transaksi baru.
4. Waktu simpan **UTC** (`timestamptz`), tampilkan WIB di UI.
5. **RLS deny-by-default.** Service role key hanya di Edge Functions, tak pernah di client.
6. Webhook Midtrans **idempoten** by `order_id`; verifikasi signature SHA512 di server.
7. **Paket = kredit**: `sesi_terpakai` ≤ `total_sesi`; booking ≤ `expires_at` (90 hari);
   kuota kedaluwarsa hangus.
8. Komplain s/d **H+3**. Auto-complete `in_progress` → `completed` **H+1** (pg_cron).
9. Reschedule **atomik** (kunci slot baru + lepas lama, 1 transaksi), tanpa ganti mode,
   maks 14 hari, tidak melewati expiry.
10. Payroll: periode dari **tanggal jadwal sesi**, cut-off **tgl 25**.
    Kalender: rekap 26 → approval 27 → transfer 28 → slip 29.
11. Absensi: check-in offline wajib dalam **radius 200 m** (geofence).
12. Honor grup dari kursi **terbooking** (no-show tetap dihitung).
13. Refund <24 jam: bayar satuan → 50% kembali; kuota paket → 1 kuota hangus.
14. Alamat lengkap hanya terbuka pasca-bayar; tak ada di API katalog publik.
15. `tutor_earnings` **append-only** (`belum_dibayar → ditahan → sudah_dibayar`).
    Tak ada kolom saldo yang di-update.
16. Satu akun = satu siswa. Registrasi <18 thn wajib checkbox izin + timestamp + kontak darurat.
17. Voucher: 1 per transaksi; kuota dikunci saat bayar dimulai (race-safe);
    **diskon 100% ditanggung platform** — tutor tetap 75% dari **harga normal**.

## Konvensi kode

- Migrasi SQL **versioned** di `supabase/migrations/`, jangan ubah skema via dashboard di prod.
- Enum pakai `text` + `check constraint` (bukan tipe `enum`), agar mudah dimigrasi.
- Aksi sensitif (payout, refund, koreksi absensi, suspend, ubah harga) tulis ke `audit_logs`.
- Semua fungsi yang menyentuh uang harus **idempoten**.
- Mobile: satu codebase, dua entry point (`main_siswa.dart` / `main_tutor.dart`);
  state Riverpod. Client config lewat `--dart-define`.
- Dashboard: React + TS + Vite; Supabase anon/publishable key dari `.env` (`VITE_*`).

## Verifikasi

```bash
# DB
supabase start && supabase db reset      # butuh Docker
# Mobile
cd apps/mobile && flutter analyze && flutter test
# Dashboard
cd apps/dashboard && npm run lint && npm run build
```

## Memori

Setiap keputusan penting → tulis catatan di `catatan/YYYY-MM-DD-topik.md`
(disalin otomatis ke vault Obsidian saat sesi ditutup). Hub: mulai dari
`catatan/2026-10-15-konteks-proyek-kelasxtra-bimbel.md`.
