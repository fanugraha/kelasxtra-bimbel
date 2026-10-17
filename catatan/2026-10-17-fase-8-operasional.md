# Fase 8 — Dashboard Operasional

## Konteks

Melengkapi dashboard admin: monitoring, keuangan, koreksi absensi, migrasi paket,
laporan voucher. Backend memakai satu RPC agregat agar dashboard tidak melakukan
banyak query berat.

## Keputusan atau temuan

- `admin_metrics(from,to)` mengembalikan JSON: bookings, ops, users, revenue
  (gross settlement, gateway fee, refund, platform share, honor), daftar performa tutor,
  dan progres siswa. Semua batas tanggal memakai **WIB**.
- `admin_correct_booking`: hanya status absensi tertentu; alasan wajib; audit log.
  Guard ledger: booking yang earning-nya sudah masuk payout / `sudah_dibayar` tidak boleh
  dikoreksi; booking yang sudah punya earning hanya boleh dikoreksi **ke** completed.
- `admin_transfer_package`: wajib `p_consent = true` (persetujuan siswa) + alasan.
  Hanya paket `active`/`expired`; tutor tujuan harus aktif. Booking lama tetap memakai
  tutor saat transaksi (snapshot), hanya booking baru ikut tutor baru.
- Laporan voucher dihitung dari `voucher_redemptions` (status used/locked) + total
  `bookings.discount` per voucher. Paket belum punya kolom voucher sehingga tidak dihitung.
- Catatan UI: beberapa aksi memakai `prompt()` agar cepat; bisa diganti modal form nanti.

## Alasan

- Satu RPC agregat mengurangi round-trip dan menjaga angka konsisten antar kartu.
- Guard ledger mencegah koreksi mengubah histori uang yang sudah dibayar.

## Langkah berikutnya

- Uji UI di browser (monitoring, keuangan, payroll, koreksi, pindah paket).
- Audit log viewer dan Fase 9 (FCM + hardening).

## Tautan terkait

- [[2026-10-17-fase-7-payroll-desain]]
- [[2026-10-17-fase-6-absensi-reschedule-komplain]]
