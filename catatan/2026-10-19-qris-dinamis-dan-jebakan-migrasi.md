# Pembayaran QRIS dinamis + dua jebakan migrasi/akses

## Konteks

Kebijakan uang baru sebelumnya memakai Midtrans Snap (halaman pilih metode). Pemilik ingin
siswa langsung melihat QRIS dengan nominal tertanam. Migrasi Snap → QRIS lewat Midtrans
**Core API** (`/v2/charge`, `payment_type: qris`) sudah dikerjakan, diterapkan ke produksi,
dan di-commit.

## Keputusan atau temuan

- `_shared/midtrans.ts`: `createSnap`/`snapBase` diganti `createQris(...)` → mengembalikan
  `{ qr_string, qr_url, expires_at }`; disimpan di `payments.raw`. Helper `cachedQris` dan
  `qrisFields` (respons tetap mengisi `redirect_url = qr_url` supaya APK lama masih jalan).
- Empat Edge memakai `createQris`: `create-snap`, `create-package-snap`,
  `create-group-seat-snap`, `create-subscription-snap`. Webhook & `paymentApply` tidak berubah
  (format & signature QRIS sama dengan Snap).
- **QRIS lama selalu dipakai ulang** selama baris `payments` masih `pending`, dengan
  amount/credit_amount dari baris itu. Alasan: `order_id` deterministik (`BK-`, `PKG-`, `GS-`)
  dan Midtrans menolak charge kedua dengan order_id sama. Tagihan jadi terkunci; permintaan
  "pakai poin" yang datang belakangan diabaikan sampai tagihan itu selesai/kedaluwarsa.
- Mobile: `qris_screen.dart` (QR via `qr_flutter`, hitung mundur, polling
  `my_payment_status` tiap 3 detik + saat app kembali aktif), `snap_screen.dart` dihapus.
- **Cadangan bila Core API belum aktif:** `createQris` mencoba `qris`, lalu `gopay`,
  lalu Snap (`enabled_payments: ['other_qris']`). Respons berisi `snap_url`; layar QRIS
  menampilkan halaman Snap itu di WebView (`webview_flutter`) dengan status tetap dipantau
  lewat polling yang sama.
- RPC `my_payment_status(p_order_id)` (security definer) hanya mengembalikan status bila
  payment milik `auth.uid()` — dipakai layar QRIS untuk tahu kapan lunas.

Dua jebakan saat penerapan:

1. **Jangan pakai `supabase db push`.** Riwayat migrasi remote diisi MCP `apply_migration`
   memakai versi timestamp (contoh `20261019051531 poin_checkout_payments_credit_amount`),
   bukan nama berkas lokal (`20261019000046_poin_checkout.sql`). `db push` karena itu
   menganggap migrasi lokal 43–47 belum jalan dan akan menjalankannya ulang. Terapkan migrasi
   baru lewat MCP `apply_migration`; berkas di `supabase/migrations/` tetap dipakai sebagai
   catatan.
2. **`revoke ... from public` tidak cukup.** Supabase memberi `execute` langsung kepada
   `anon`/`authenticated`/`service_role` saat fungsi dibuat, jadi status nyata adalah
   `postgres | anon | authenticated | service_role`. Fungsi baru harus dicabut dari anon
   eksplisit: `revoke execute on function ... from anon` (lihat juga migrasi
   `hardening_poin_ganti_hari`).

## Alasan

QRIS dinamis memangkas langkah (nominal tertanam, tak perlu pilih metode) dan lebih cocok
untuk pengguna HP di Indonesia; reuse QR menjaga idempotensi order_id yang deterministik.
Dua jebakan di atas menimbulkan risiko diam: `db push` bisa mengulang migrasi (berbahaya di
produksi), dan `revoke from public` memberi rasa aman palsu.

## Langkah berikutnya

- Uji sandbox end-to-end: bayar QRIS Simulator → webhook → `payments.status = settlement` →
  layar QRIS menutup sendiri; uji QR dipakai ulang, QR kedaluwarsa, dan lunas penuh poin.
- Pastikan metode QRIS aktif di dashboard Midtrans (sandbox & production) — dikerjakan pemilik.
- Opsional: tombol "Simpan QR ke galeri" dan perbaikan error tipe supabase-js di Edge.
