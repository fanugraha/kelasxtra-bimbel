# Fase 2 — Booking Mobile + Snap + Timeout

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

16 Okt 2026. Setelah konek Midtrans, dibangun alur booking siswa end-to-end + tutup
celah timeout. Diuji di HP Android pemilik dengan Midtrans **sandbox asli**.

## Keputusan atau temuan

- **Alur mobile**: profil tutor → "Pesan Sesi" → pilih Mapel·Jenjang, Mode, Durasi → slot
  jadwal (dari `tutor_availability`) → tanggal → jam mulai → alamat (bila offline) →
  harga dari `price_matrix` → `create-snap` → **Snap di WebView** (`webview_flutter`).
  Tab **Jadwal** menampilkan booking + status.
- **Bukti E2E (HP, 16 Okt)**: `create-snap` 200 → Snap → bayar → Midtrans kirim webhook
  (UA `Veritrans`, 200) → booking `confirmed`, payment `settlement`. Harga & konversi
  WIB→UTC benar, lock 30 menit terisi.
- **Timeout**: `expire_stale_bookings()` + `pg_cron` tiap 5 menit
  (migrasi `...00011_expire_stale_bookings`). Diuji: booking `pending_payment` lewat lock →
  `expired`, payment `pending` → `expire`. `execute` dicabut dari anon/authenticated.
- **Advisor keamanan** (migrasi `...00012_security_hardening`): `set_updated_at` diberi
  `search_path`; `execute` `handle_new_user` dicabut dari publik. Sisa peringatan =
  disengaja/tak-bermasalah: view definer `tutor_catalog`, `is_admin`/`is_admin_role`/`set_price`
  (dipakai RLS / berpagar `is_admin()`), `pg_net` di schema public (bawaan Supabase).
- **Web** tak bisa untuk Snap (`webview_flutter` tanpa dukungan web) → uji Snap wajib di HP.

## Alasan

- Snap dibuka lewat `redirect_url` di WebView (bukan snap.js embed) supaya ringkas; tombol
  "Selesai" + invalidate daftar booking sebagai penutup (ponytail: callback Snap terstruktur
  menyusul bila perlu).
- Auto-expire lewat `pg_cron` (bukan Edge Function terjadwal) = paling ringkas di Supabase.

## Sisa kecil

- Webhook menimpa `payments.raw` sehingga `snap_token` hilang (efek: bayar ulang saat pending
  meregenerasi token Snap — tetap jalan). Bisa diperbaiki: gabung, bukan timpa.
- Jalur booking gagal (deny/cancel) belum diuji dengan webhook asli.
- Voucher & filter katalog lanjutan belum.

## Langkah berikutnya

- Uji jalur gagal/duplikat webhook; voucher di checkout; filter mode/harga/rating.
- Isi harga final (O7) lewat dashboard.

## Tautan terkait

- [[2026-10-15-fase-2-katalog-booking]]
- [[2026-10-16-ui-fondasi-desain]]
- [[2026-10-15-keputusan-teknis-kelasxtra]]
