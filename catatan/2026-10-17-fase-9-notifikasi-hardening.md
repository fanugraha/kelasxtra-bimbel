# Fase 9 — Notifikasi & Hardening

## Konteks

Menutup MVP: antrean notifikasi, Edge pengirim FCM, inbox mobile, rate limit,
audit log viewer, dan perbaikan temuan security advisor.

## Keputusan atau temuan

- **Antrean dulu, push kemudian**: semua peristiwa penting menulis ke `notifications`
  lewat trigger (booking, reschedule, komplain, payroll, langganan). Edge `send-push`
  membaca status `pending`, mengirim FCM HTTP v1, lalu menandai `sent`/`failed`.
  Selama env belum diset, notifikasi tetap bisa dibaca di inbox mobile.
- **FCM mobile belum aktif**: repo belum punya `google-services.json` dan plugin
  Google Services di Gradle. Tanpa itu `firebase_messaging` tidak bisa dipakai.
- **Endpoint push tidak terbuka**: `verify_jwt=false` tetapi wajib header
  `x-cron-secret`; tanpa env fungsi membalas 503.
- **Rate limit** disimpan di tabel `rate_limits` (key + window + count), fungsi
  `check_rate_limit` hanya dipanggil dari definer. Chat dibatasi 20 pesan/menit/user.
- **Temuan advisor**: 41 fungsi SECURITY DEFINER bisa dieksekusi `anon`. Diperbaiki
  dengan `revoke execute ... from public, anon` lalu grant `authenticated` hanya
  untuk daftar RPC klien. Helper RLS tetap diberi grant agar policy jalan.
- `rate_limits` sengaja RLS tanpa policy (hanya definer).
- Security definer view (`tutor_catalog`, `bookings_visible`, dll.) tetap disengaja
  dan dibatasi kolom/baris; advisor akan terus menandainya.

## Alasan

- Antrean membuat pengiriman idempoten dan tahan gagal; tidak memperlambat transaksi.
- Grant eksplisit mengurangi permukaan serangan tanpa memutus RLS.

## Langkah berikutnya

- Set env FCM + config Firebase Android/iOS, jadwalkan `send-push`.
- Backup/restore check dan uji beban ringan.
- Rekonsiliasi Midtrans vs `payments` sebelum go-live.

## Tautan terkait

- [[2026-10-17-fase-8-operasional]]
- [[2026-10-17-fase-7-payroll-desain]]
