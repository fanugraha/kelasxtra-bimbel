# Arsitektur Teknis

Ringkasan arsitektur. Acuan lengkap: [brief-implementasi-v2.0.md](brief-implementasi-v2.0.md).

## Tech stack

| Komponen | Pilihan |
|---|---|
| Mobile (siswa & tutor) | Flutter, **Riverpod**, `supabase-flutter` |
| Dashboard admin | React + TypeScript + Vite |
| Backend | Supabase: PostgreSQL + Auth + Storage + Edge Functions + Realtime + pg_cron |
| Pembayaran | Midtrans: Snap (sekali bayar), recurring (langganan), webhook |
| Push | Firebase Cloud Messaging (FCM) |
| Peta/lokasi | Geolocator (Flutter) untuk geofence check-in |

## Batas kepercayaan (trust boundary)

- Client (mobile/dashboard) hanya pakai **anon/publishable key**. Dilindungi RLS.
- **Service role key** hanya di Edge Functions, tidak pernah di client.
- Webhook Midtrans diverifikasi signature SHA512 di server; idempoten by `order_id`.

## State machine booking (11 status)

```
pending_payment → confirmed → in_progress → completed
                        ↘ cancelled
pending_payment → expired          (slot lock 30 menit lewat)
confirmed/in_progress → no_show_tutor / no_show_student
completed → disputed               (buka komplain s/d H+3 via CS)
```

Aturan terkait:
- Slot tutor **auto-accept** (tanpa terima/tolak).
- Auto-complete: `in_progress` tanpa komplain s/d **H+1** → `completed` (pg_cron).
- Reschedule **atomik** (kunci slot baru + lepas slot lama 1 transaksi), tanpa ganti mode, maks 14 hari, tidak melewati expiry paket.

## Pembayaran & bagi hasil

- Uang selalu **integer rupiah**.
- `tutor_share = floor(harga × 75 / 100)`, `platform_share = harga − tutor_share`.
- Harga di-**snapshot** ke booking/paket saat transaksi; perubahan price matrix hanya untuk transaksi baru.
- **Ledger append-only** `tutor_earnings`; status: `belum_dibayar → ditahan → sudah_dibayar`. Tidak ada kolom saldo yang di-update.

## Payroll bulanan

- Periode dihitung dari **tanggal jadwal sesi** (bukan tanggal completed).
- Cut-off tgl **25**. Kalender: rekap 26 → approval 27 → transfer 28 → slip 29.
- Four-eyes approval, ekspor daftar transfer, tombol "tandai sudah ditransfer".

## Paket = kredit

- `sesi_terpakai` bertambah per booking; ≤ `total_sesi`; booking ≤ `expires_at`; kuota kedaluwarsa hangus.
- Masa berlaku **90 hari**; diskon 4/8/12 sesi = 0%/5%/10%; terikat **1 tutor**.

## Voucher

- 1 voucher per transaksi; validasi real-time saat checkout.
- Kuota dikunci saat pembayaran dimulai (race-safe), dilepas bila gagal.
- **Diskon 100% ditanggung platform**; tutor tetap 75% dari **harga normal**.
- Refund penuh mengembalikan kuota per-siswa.

## Flavor mobile

Satu codebase Flutter, dua entry point: `main_siswa.dart` & `main_tutor.dart`,
diplih lewat `appFlavorProvider`. Lihat `apps/mobile/lib/core/`.
