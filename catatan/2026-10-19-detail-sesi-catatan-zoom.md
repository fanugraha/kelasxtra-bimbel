# Detail Sesi: catatan tentor & tautan Zoom (19 Okt 2026)

## Konteks
Pemilik meminta tinjauan (product design + analis sistem) halaman "Detail Sesi": tanpa
harga/status pembayaran, jadwal dua lapis per tentor, catatan tentor wajib, dan tombol
Gabung Zoom. Hasil tinjauan: dua dari empat permintaan ternyata soal level **daftar**
(bukan satu sesi), dan satu permintaan berbenturan dengan penjaga teks (guard) yang
sudah ada.

## Keputusan atau temuan
1. **Harga keluar dari Detail Sesi** (halaman Riwayat transaksi yang memuat uang).
   `booking_summary.dart` kini hanya identitas + jadwal + tempat.
2. **"Kelompok per tentor dua lapis" dipasang di Jadwal, bukan Detail Sesi** — satu sesi
   hanya punya satu tentor. Jadwal: Lapis 1 kartu tentor (foto/nama/jumlah sesi/mapel/
   sesi berikutnya) yang bisa dibuka-tutup, Lapis 2 kartu sesinya. Untuk tutor, Lapis 1 =
   siswa (siswa tidak punya foto → inisial). Pengelompokan per tanggal yang lama diganti.
3. **Catatan sesi sudah wajib, tapi ada celah**: `complete_booking` menolak tanpa
   catatan, namun cron `auto_complete_bookings` (H+1) menuntaskan sesi **tanpa** syarat
   catatan → sesi selesai tanpa catatan itu nyata. `save_session_note` tidak memeriksa
   status, jadi solusinya cukup UI: tombol isi catatan juga muncul di sesi `completed`
   yang belum punya catatan.
4. **Zoom tidak ada sama sekali** (tidak ada kolom/integrasi, `url_launcher` belum
   dipasang). Dipilih **tautan manual per sesi**, bukan integrasi Zoom API: integrasi
   menuntut satu akun Zoom milik platform + OAuth server-to-server, dan semua meeting
   jadi milik akun platform — operasional salah, sedangkan tentor sudah punya akun Zoom
   sendiri.
5. **Temuan penting**: penjaga teks `guard_text` (Fase 10) menolak **semua** tautan,
   jadi tautan Zoom tidak boleh lewat catatan/chat. Kolom `bookings.meeting_url` karena
   itu sengaja **tidak** dipasangi `guard_text`; gantinya validasi domain ketat
   (`https` + `zoom.us`/`zoom.com`, hanya sesi online). Tautan tidak ditulis ke
   `audit_logs` (hanya "terisi/kosong") supaya tidak bocor ke log.
6. **Kolom baru**: `session_notes.next_step` (tugas/saran berikutnya) dan
   `bookings.meeting_url` + `meeting_url_set_at`; `bookings_visible` ditambah
   `meeting_url` (disembunyikan selama belum lunas, seperti `address`). RPC baru
   `set_session_meeting_url`; `save_session_note` bertambah `p_next_step`.

## Alasan
- Aturan jendela waktu tombol Gabung (aktif 15 menit sebelum jadwal s/d 15 menit setelah
  sesi berakhir) ditaruh di `core/meeting_link.dart` karena dipakai dua fitur (Detail Sesi
  dan Jadwal) — sesuai aturan struktur mobile: kode bersama milik `core/`.
- Validasi domain di DB (trigger), bukan hanya di app, supaya dashboard/SQL manual tidak
  bisa menyelundupkan tautan asing ke kolom yang bebas dari `guard_text` itu.

## Langkah berikutnya
- Uji di HP (HP sedang tidak terdeteksi): Detail Sesi baru + Jadwal dua lapis + tombol
  Gabung Zoom dengan sesi online berjadwal dekat.
- Bila nanti mau otomatis: pertimbangkan `package_purchases.meeting_url` sebagai tautan
  bawaan paket + opsi "salin ke semua sesi mendatang" agar tentor tidak menempel berulang.
- Catatan tutor/admin: sesi yang tuntas otomatis tanpa catatan sebaiknya ditegur ringan
  (mis. pengingat push) agar celah butir 3 benar-benar tertutup.
