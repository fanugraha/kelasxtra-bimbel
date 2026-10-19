# Penjaga race slot pembayaran (19 Okt 2026)

## Konteks

Ada tiga celah yang bisa membuat sesi dobel atau siswa kehilangan slot yang sudah dibayar:

1. `bookings` tidak punya penjaga slot di level database — pemeriksaan hanya di aplikasi
   (`create-snap` hanya melihat booking milik siswa yang sama; `reserve_package_schedule`
   mengandalkan advisory lock). Dua siswa bisa menahan slot tutor yang sama.
2. `expire_stale_bookings` & `expire_stale_group_seats` melepas tahanan hanya dari
   `lock_expires_at`. Bila webhook `settlement` datang setelah slot dilepas, pembayaran
   tetap dikonfirmasi padahal slot sudah diambil orang lain.
3. Webhook lama menelan pesan error (`console.error`) sehingga pembayaran nyangkut tanpa
   ada yang tahu.

## Keputusan atau temuan

- **Slot tutor/ siswa tidak boleh dobel** ditegakkan DB lewat dua exclusion constraint
  (`bookings_no_tutor_overlap`, `bookings_no_student_overlap`, butuh `btree_gist`) yang
  berlaku untuk status pengunci `pending_payment`/`confirmed`/`in_progress`.
- **Pelepasan tahanan hanya berdasarkan keputusan Midtrans** (expire/deny/cancel) — bukan
  waktu. Penentu tunggal: webhook + Edge `reconcile-payments` yang bertanya
  `GET /v2/{order_id}/status`.
- **Satu modul logika bersama** `_shared/paymentApply.ts` dipakai webhook dan sapuan
  berkala, supaya kedua jalur tidak pernah berbeda perilaku.
- **Gagal otomatis tidak boleh senyap**: `payments.review_required`/`review_note` +
  `audit_logs` menandai pembayaran yang perlu ditangani admin. Tindak lanjutnya di
  dashboard (**Pembayaran Perlu Ditinjau**) lewat Edge `resolve-payment-review`:
  **Proses ulang** (jalankan ulang aktivasi; aman karena semua RPC lanjutan dijaga status)
  atau **Sudah ditangani** + catatan wajib.
- Temuan teknis: `timestamptz + interval` bertanda STABLE di Postgres, jadi tidak bisa
  dipakai di index expression (error `42P17`). Solusinya fungsi SQL IMMUTABLE
  `public.booking_slot_range(ts, menit)` yang berhitung lewat epoch.
- Uji nyata di produksi (dibungkus rollback): insert bertumpang ditolak, slot bebas
  diterima, data uji tidak tertinggal.
- Pesan galat mentah penjaga slot (`exclusion_violation`) diterjemahkan jadi kalimat ramah
  di `lib/core/errors.dart` (`cleanError`) supaya siswa membaca "Slot ini baru saja terisi.
  Silakan pilih jam lain, ya."

## Alasan

Pemilik memutuskan tidak boleh ada kasus "sudah bayar tapi slotnya diambil orang lain".
Menahan slot sampai Midtrans memastikan transaksi mati membuat pembayaran yang masuk
terlambat tetap mendapat slotnya; risiko yang tersisa hanyalah slot tertahan lebih lama
(masih bisa dibereskan admin), bukan sesi dobel atau refund.

## Langkah berikutnya

- Set `PUSH_CRON_SECRET` lalu jadwalkan `reconcile-payments` tiap 1–5 menit (tanpa ini
  tahanan basi hanya menggantung, tidak dobel).
- Uji sandbox: bayar paket sampai lunas, dan biarkan satu tagihan kedaluwarsa agar slot
  baru lepas setelah Midtrans bilang `expire`.
- Halaman tindak lanjut sudah ada (dashboard → **Pembayaran Perlu Ditinjau**), tapi belum
  pernah diuji klik karena di produksi belum ada pembayaran bertanda `review_required`.
