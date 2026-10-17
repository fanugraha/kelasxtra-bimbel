# Fase 6 — Absensi, Reschedule, Komplain, Pesan

## Konteks

Melanjutkan Fase 5 yang teruji di HP. Fase 6 mencakup absensi (check-in tutor, kehadiran
siswa, no-show), auto-complete H+1, reschedule, pembatalan/refund, komplain, ulasan,
thread pesan per booking, dan ledger `tutor_earnings`.

## Keputusan atau temuan

- **Batas reschedule 2x per booking** (server-side, kolom `reschedule_count`).
  Brief hanya minta counter; angka 2 dipilih agar tidak disalahgunakan.
- **Auto-complete H+1** dihitung dari `scheduled_at + durasi + 1 hari` (bukan `updated_at`),
  dan ditunda bila ada komplain `open`/`in_review`.
- **Refund tidak memindahkan dana.** Semua refund (batal maupun komplain) hanya
  dihitung & dicatat (`bookings.refund_amount`, `complaints.refund_nominal`);
  pengembalian manual via dashboard Midtrans — konsisten dengan refund paket.
- **Batal**: >24 jam → refund penuh (atau kuota paket kembali); ≤24 jam → 50% tunai
  (kuota paket hangus).
- **Geofence offline** butuh titik acuan. Ditambahkan `bookings.location_lat/lng`
  (dan `rooms.lat/lng`), tetapi belum ada UI pengisian → check-in offline hanya
  menyimpan koordinat tutor tanpa menolak jarak bila acuan null. Perlu dilengkapi.
- **Penyaringan nomor telepon** di chat: regex `(\+?62|0)8...` diganti
  `[nomor disembunyikan]` dan pesan ditandai `flagged` untuk admin.
- **RLS jebakan penting**: policy tabel baru tidak boleh subquery langsung ke
  `bookings` — SELECT tabel itu sudah dicabut dari client (migrasi 00013), sehingga
  muncul "permission denied for table bookings". Solusi: helper `security definer`
  (`booking_participant`, `booking_is_student`, `thread_participant`).
- Uji backend pakai transaksi `begin … rollback` dengan `request.jwt.claims` agar
  `auth.uid()` berperan sebagai siswa/tutor/admin — tidak mengotori data.

## Alasan

- Ledger `tutor_earnings` dibuat sekali per booking (`on conflict do nothing`) dan
  hanya berubah status, sesuai aturan append-only.
- Rating tutor dihitung ulang dari rata-rata ulasan setiap kali ulasan masuk.

## Uji flavor tutor di HP (17 Okt)

APK `main_tutor.dart` dipasang di HP `e68890180406`. Ditemukan & diperbaiki:
- flavor tutor belum punya rute `/jadwal` (hanya tab Beranda/Profil) → ditambah tab **Jadwal**;
  tombol "Jadwal Mengajar" di Beranda kini membuka tab itu.
- sesi siswa bisa masuk flavor tutor tanpa peringatan → Beranda tutor menampilkan
  "Akun ini bukan tutor" + tombol keluar bila role bukan tutor.
- daftar jadwal tutor kini difilter `tutor_id = auth.uid()` (`tutorBookingsProvider`).

Alur teruji: login tutor → Jadwal → Mulai sesi (status `Berlangsung`) → isi catatan sesi →
Selesaikan sesi → status `completed`, `session_notes` terisi, `tutor_earnings`
56.250/18.750 `belum_dibayar`; pesan chat terkirim dari akun tutor.

## Sisa Fase 6 (17 Okt, lanjutan)

- **Absensi grup di UI tutor**: layar `/absensi-grup` (Beranda tutor → Absensi Grup) membaca
  view `group_attendance_visible` (definer, difilter `tutor_id = auth.uid()`), qid centang
  Hadir/Izin/Alpa per siswa per pertemuan lewat RPC `mark_group_attendance`.
  Diuji via SQL: tutor pemilik melihat baris, tutor lain 0 baris, status tersimpan.
- **Koordinat ruangan**: form & tabel Ruangan (dashboard) kini punya lat/lng sebagai acuan
  geofence 200 m. Titik lokasi booking privat masih kosong (belum ada pemilih lokasi saat checkout).

## Langkah berikutnya

- Uji flavor tutor di HP: check-in → catatan sesi → selesai.
- UI kehadiran grup (RPC `mark_group_attendance` sudah ada).
- Isi titik lokasi ruangan/booking agar geofence 200 m benar-benar menolak.
- Lanjut Fase 7 (payroll bulanan dari ledger).

## Tautan terkait

- [[2026-10-17-fase-5-bank-soal]]
- [[2026-10-15-rencana-pengembangan]]
