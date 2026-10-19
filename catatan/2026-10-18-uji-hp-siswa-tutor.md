# Uji fitur di HP — siswa & tutor

## Konteks
Uji manual build rilis di Redmi 9 (Android 12) tanggal 18 Okt 2026, memakai akun demo.
Data uji yang mengubah state (booking, earning, ulasan, absensi, paket pending) sudah
dikembalikan lewat SQL setelah pengujian.

## Hasil yang lolos
- Siswa: katalog + filter mapel, profil tutor, pilih slot (online/offline), voucher
  HEMAT10 (85.000 → 76.500), Snap terbuka, chat terkirim, date/time picker reschedule,
  ulasan 5★, tryout 20 soal (6 benar, nilai 30, durasi 435 dtk, statistik topik
  ter-update), kelas grup (1/5 kursi, Rp570.000), Paket Saya kosong, Beli Paket
  8 sesi Rp646.000 + Snap terbuka, notifikasi kosong, tema gelap/terang, profil siswa.
- Tutor: guard "akun ini bukan tutor", Jadwal, Mulai sesi (check-in online), catatan
  sesi, selesaikan sesi → earning 56.250/18.750 `belum_dibayar`, tab Gaji (estimasi
  112.500), Absensi Grup (tandai hadir tersimpan), profil tutor.

## Temuan/bug
1. **Data akun lama tetap tampil setelah ganti akun** (nama, profil, guard tutor) sampai
   aplikasi di-force stop. Provider profil/sesi tidak di-invalidate saat auth berubah —
   berisiko privasi di HP bersama.
2. Tombol "Beri ulasan" tetap muncul setelah ulasan terkirim (duplikat ditolak DB).
3. Soal matematika memakai `^` ASCII (`x^2`, `m/s^2`) dan dirender sebagai teks biasa;
   belum ada renderer matematika di layar bank soal. `flutter_math_fork` sudah ada di
   pubspec tetapi belum dipakai.
4. Date/time picker berbahasa Inggris (lokalisasi Material belum diatur).
5. Layar booking menampilkan "Tutor belum punya jadwal untuk mode ini" sebelum mode
   dipilih (pesan menyesatkan).
6. Daftar pertemuan kelas grup tampil urut terbaru → terlama (8 → 1).
7. Tabel `notifications` belum diisi produser mana pun, jadi layar notifikasi selalu
   kosong.

## Langkah berikutnya
- Invalidate provider terkait (profil, booking, jadwal, langganan) saat `onAuthStateChange`.
- Render soal/pembahasan dengan `flutter_math_fork` (konten perlu format TeX/LaTeX).
- Tambah `flutter_localizations` + locale `id` untuk picker.
- Sembunyikan aksi ulasan bila sudah ada review.

## Perbaikan setelah uji (18 Okt)
- Provider data pengguna (`myProfile`, booking, paket, langganan, statistik, absensi,
  notifikasi, payout) kini ikut berubah saat status auth berubah — ganti akun langsung
  menampilkan data akun baru.
- `BookingDetail.hasReview` + tombol "Beri ulasan" disembunyikan setelah ada ulasan.
- `MathText` mengubah notasi sehari-hari menjadi TeX: `akar3` → √3, `x^2` → x²,
  `tan 60 derajat` → tan 60°, `100 derajat Celsius` → 100 °C, `pi` → π,
  `2 x 3` → 2 × 3, serta dukungan `$...$`.
- Lokalisasi Material `id` (picker tanggal/jam Indonesia).
- Pesan mode belum dipilih pada layar booking diperbaiki.
- Jadwal kelas grup diurutkan 1 → 8.
- `flutter analyze` bersih, 14 test lulus; APK siswa terpasang.

### Lanjutan perbaikan simbol matematika
Akar masalah "banyak yang tidak terbaca": `String.split()` di Dart membuang bagian
penanda hasil regex capture, sehingga potongan `$...$` (rumus) hilang sebelum dirender.
Diganti tokenizer berbasis `allMatches` yang menyertakan potongan rumus.
Ditambah konversi: notasi ilmiah (`6,02 x 10^23` → 6,02 × 10²³), rumus kimia
(`CO2` → CO₂), indeks (`v0` → v₀), perkalian desimal, silang genetika (`Aa x Aa` → Aa × Aa),
dan seluruh opsi jawaban yang berupa ekspresi dirender sebagai satu rumus.
Tes render memastikan widget `Math` benar-benar dibuat dan berukuran > 0.

### Penulisan soal tanpa ribet (CMS)
Pratinjau Bank Soal di dashboard sekarang memakai konversi yang sama dengan mobile
(`apps/dashboard/src/lib/mathText.ts`), jadi penulis cukup mengetik notasi biasa:
`akar3`, `x^2`, `cos 60 derajat`, `6,02 x 10^23`, `CO2`. `$...$` tetap didukung untuk
rumus kompleks. Teks tersimpan apa adanya (tanpa migrasi data). `npm run build` lolos;
contoh konversi diuji lewat skrip cepat.

### Redesign alur booking jadi wizard 3 langkah
Layar booking sebelumnya menumpuk 9 keputusan dalam satu halaman. Diubah jadi wizard
`apps/mobile/lib/features/booking/booking_screen.dart`:
1) Mapel & durasi (harga tampil di sini), 2) Jadwal (hari/slot, tanggal, jam),
3) Ringkasan & bayar (alamat bila offline, cara bayar, voucher, total, CTA).
Ada bar progres "Langkah X dari 3" + tombol Kembali; voucher dipindah ke ringkasan
dan disembunyikan di balik tautan agar tidak menonjol; ringkasan punya tautan "Ubah".
Dasar: riset Stripe/Baymard/DeveloperUX (indikator progres, CTA bawah, ringkasan).
Diverifikasi di HP: step 1-3, voucher HEMAT10 → total Rp76.500. `flutter analyze`
bersih, 18 test lulus.

### Fase 10 (mulai): chat gaya Shopee + penjaga anti bocor
Diskusi dengan pemilik, keputusan: 1 percakapan per tutor (bukan per sesi), tombol
chat hanya aktif bila sudah ada booking, kiriman berisi data bocor DITOLAK (bukan
disensor), dan penyaringan dipasang di semua teks buatan pengguna.
Migrasi `supabase/migrations/20261018000035_fase10_chat.sql`:
- Tabel `conversations` (unik per siswa–tutor) + `conversation_messages` (ada
  `read_at`) + `moderation_flags`; riwayat `booking_threads` dipindahkan (backfill).
- `guard_compact`/`guard_loose_hit`/`guard_number_hit`/`guard_check`/`guard_text`:
  normalisasi (angka yang dieja, pemisah dibuang) lalu deteksi nomor HP, email,
  tautan, akun sosial, dan ajakan bayar luar. Kata bank/dompet digital hanya
  ditandai bila ada angka, supaya "materi tentang dana pensiun" tidak ikut ditolak.
- Penjaga dipasang lewat trigger di bio tutor, catatan sesi, ulasan, komplain,
  pesan chat; `send_booking_message` diubah dari sensor menjadi tolak.
- RPC `ensure_conversation`, `send_conversation_message` (balas jsonb), 
  `mark_conversation_read`; view `my_conversations` (peer nama/avatar, unread);
  `conversation_messages` masuk publikasi realtime.
Catatan penting: trigger yang menolak lewat EXCEPTION membuat baris
`moderation_flags` ikut ter-rollback, karena itu jalur chat memakai `guard_check`
+ balasan jsonb agar catatan pelanggaran tetap tersimpan; jalur trigger mencatat
ke log server (`raise log kx_guard`). Dasar: riset Stripe/Baymard/DeveloperUX.
Fase berikut: tab Chat di aplikasi + layar moderasi dashboard.

### Fase 2: tampilan chat di aplikasi (selesai diuji)
Keputusan pemilik: tab Chat di menu bawah; untuk tutor tab Profil keluar dari menu
bawah (dibuka dari ikon foto di Beranda) agar tetap 5 tab. Notifikasi pesan masuk
cukup di dalam aplikasi dulu (FCM ditunda). Tanda dibaca gaya WA (centang satu/dua).

Yang dibuat:
- `features/chat/`: repository (view `my_conversations`, RPC, stream realtime),
  provider, layar daftar chat (pencarian, lencana unread, waktu ringkas), ruang
  chat (gelembung, pita pengingat keamanan, centang, "Dibaca").
- Lencana jumlah belum dibaca di tab Chat (AppShell).
- Pita notifikasi "Pesan baru dari ..." + tombol Buka saat aplikasi terbuka;
  pesan yang sedang dibuka tidak memunculkan pita.
- Daftar Notifikasi: notifikasi chat bisa diketuk dan langsung membuka ruang
  obrolan; daftar disegarkan setiap kali layar dibuka.
- Chat per-sesi lama di layar detail sesi diganti tombol "Chat dengan tutor/siswa".
- Tombol chat di profil tutor (sebelum ada booking, server menolak dengan pesan
  "Chat tersedia setelah kamu memesan sesi...").

Masalah yang ditemukan & diperbaiki (penting untuk fitur realtime lain):
- `.order('created_at')` pada stream Supabase defaultnya menurun, sehingga pesan
  baru tampil di atas dan pengguna merasa "tidak terkirim". Perbaikan: `ascending: true`.
- Sinyal realtime berupa `StreamProvider<void>` tidak memicu pembaruan Riverpod
  karena nilai dianggap sama; diganti penghitung int yang selalu berubah.
- Daftar notifikasi memakai cache lama saat dibuka; disegarkan di `initState`.
- Alur kerja diubah ke hot reload (`./run-dev.sh`, tombol r) agar uji perubahan
  cepat; build rilis hanya untuk pengecekan akhir.

### Fase 3: layar moderasi dashboard (dibuat, uji browser belum)
Catatan pelanggaran kini menyimpan rujukan (ref_table/ref_id) sehingga admin bisa
membuka percakapan yang memicunya; jalur chat mencatat id percakapan, jalur trigger
mencatat id barisnya. Dua RPC admin baru: tandai ditinjau (dengan catatan) dan kirim
peringatan (masuk Notifikasi pengguna); keduanya menulis jejak di audit_logs dan
hanya bisa dipanggil admin (dicek di dalam fungsi, akses anon dicabut).

Di dashboard ada modul "Moderasi Chat": daftar catatan (belum ditinjau/semua),
dialog konteks berisi riwayat percakapan, tombol Tinjau, Peringatkan, dan
Tangguhkan (khusus tutor, lewat fungsi manage-tutor). Penangguhan untuk siswa tidak
ada karena skema hanya punya suspended_at pada tutors.

Diuji lewat SQL: sebagai admin semua terbaca; sebagai siswa catatan tidak terlihat
dan RPC admin ditolak. Uji tampilan di browser belum dilakukan (butuh login admin).

### Dua APK: siswa dan tutor dipisah (18 Okt 2026)
Aplikasi mobile sekarang punya flavor Android sehingga terpasang sebagai dua aplikasi
berdampingan: "Kelasxtra" (id.kelasxtra.bimbel) dan "Kelasxtra Tutor"
(id.kelasxtra.tutor). Nama aplikasi diambil dari @string/app_name yang diisi per
flavor, jadi satu manifest saja. Skrip build menjalankan flavor yang cocok dengan
entry point (main_siswa/main_tutor) dan bisa MODE=debug untuk build cepat saat uji.

Alasan: sebelumnya satu id paket sehingga memasang app tutor menimpa app siswa dan
hanya ada satu ikon; memisahkan juga membuka jalan notifikasi dan daftar toko
masing-masing per peran.

Catatan kecil: saat profil belum selesai dimuat, sapaan Beranda sempat menampilkan
alamat email akun; sebaiknya diganti teks netral (mis. "Hai"). Belum dikerjakan.
