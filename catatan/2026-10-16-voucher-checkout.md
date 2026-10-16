# Voucher di Checkout

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

16 Okt 2026. Melengkapi Fase 2: kode voucher dipakai saat checkout, kuota dikunci
race-safe saat pembayaran dimulai, dilepas bila gagal.

## Keputusan atau temuan

- **RPC di DB** (migrasi `...00014_voucher_checkout`, `...00015_voucher_release_redemption`):
  - `voucher_validate(code, student, price)` — validasi bersama (aktif, masa berlaku,
    min belanja, kuota, batas per-siswa). Raise errcode `22023` bila ditolak.
  - `check_voucher(code, price)` — pratinjau diskon untuk siswa login (pakai `auth.uid()`),
    **tanpa** kunci kuota. Grant ke `authenticated`.
  - `reserve_voucher(code, student, price)` — kunci kuota **atomik**
    (`update vouchers set used = used + 1 where ... and used < quota`), catat redemption
    `locked`, kembalikan diskon. Hanya `service_role`.
  - `attach_voucher_redemption`, `release_voucher_for_booking`, `release_voucher_redemption`,
    `consume_voucher_for_booking` — hanya `service_role`.
- **Kolom baru** `voucher_redemptions.booking_id` → redemption bisa dilepas per booking.
- **Diskon**: percent → `floor(price × value/100)` (dibatasi ≤ price); nominal → `min(value, price)`.
  Snapshot ke `bookings.discount`; `amount_due` (generated) = price − discount; Snap memakai `amount_due`.
- **create-snap**: terima `voucher_code`; kunci voucher **sebelum** insert booking; bila insert
  booking gagal → lepas kunci; bila Snap gagal → lepas kunci + hapus booking/payment (tak nyangkut).
  Path pakai-ulang booking pending tidak mengunci ulang (diskon dari booking lama).
- **webhook**: settlement → `consume_voucher_for_booking` (status `used`); deny/cancel/expire/
  refund → `release_voucher_for_booking` (kuota kembali).
- **Mobile**: kolom kode + tombol Pakai (pratinjau diskon), kartu harga menampilkan
  harga normal (coret), diskon, dan total. Diskon direset bila mapel/mode/durasi berubah.

## Alasan

- Kunci kuota di DB (bukan app) karena hanya DB yang bisa menjamin bebas balapan (oversell).
- Pratinjau tanpa kunci → siswa bisa lihat diskon sebelum bayar; kuota baru dikunci saat bayar
  (sesuai brief), dan dilepas otomatis bila gagal/kedaluwarsa.

## Verifikasi

- Login siswa nyata → `create-snap` + `HEMAT10`: harga 85.000, diskon 8.500, bayar **76.500**;
  `vouchers.used` 0→1; redemption `locked` + tertaut booking.
- Ditolak: pakai voucher sama dua kali (batas per-siswa), kode tak dikenal. Tak ada booking yatim.
- `release_voucher_for_booking` → redemption `released`, `used` kembali 0.
- Voucher contoh **HEMAT10** (10%, kuota 5, per-siswa 1) disisakan untuk uji di HP.

## Langkah berikutnya

- Filter katalog (mode/harga/rating); isi harga final O7.

## Tautan terkait

- [[2026-10-16-booking-midtrans-timeout]]
- [[2026-10-15-fase-2-katalog-booking]]
