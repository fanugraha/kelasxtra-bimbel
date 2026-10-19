# Rombak UX mobile siswa: Jadwal 3 langkah, Detail Sesi, Profil Tutor, Beli Paket 2 langkah, grafik Kekuatan (19 Okt 2026)

## Konteks
Pemilik meminta (dengan gambar referensi dari Dribbble) agar beberapa layar siswa
lebih rapi dan mudah dipahami anak SMP–SMA: Jadwal, Detail Sesi, Profil Tutor,
Beli Paket, dan Beranda › Kekuatan & kelemahan. Dikerjakan di sesi Claude Code
(bukan OpenCode). Semua perubahan hanya di `apps/mobile` + data dummy di Supabase
ter-link; **tidak ada migrasi baru**.

## Keputusan atau temuan

### 1. Jadwal dipecah 3 langkah (gantikan "jadwal dua lapis")
- **Langkah 1 `/jadwal`**: kartu "Sesi berikutnya" (pil waktu hidup, tombol Gabung
  Zoom yang menyala sendiri tiap 30 dtk), strip 7 hari, lalu daftar **tutor**
  (aplikasi tutor: daftar **siswa**) urut dari sesi terdekat; tutor yang tinggal
  riwayat di bagian "Kelas sebelumnya". Kartu tutor punya bar "Progres kelas".
- **Langkah 2 `/jadwal/:personId`** (rute baru, top-level): hero tonal + foto,
  3 kotak angka (Akan datang / Selesai / Jam belajar), tab Jadwal | Riwayat kelas.
- **Langkah 3**: ketuk sesi → `/sesi/:id` (Detail Sesi).
- Logika murni di `features/jadwal/jadwal_grouping.dart` (+ tes). Semua dari
  `jadwalProvider` yang sudah ada — tidak ada query baru.
- Riwayat kelas = `completed`/`cancelled`/`refunded`; `pending_payment` &
  `expired` disembunyikan. Jam belajar = jumlah `duration_minutes` sesi
  `completed` (durasi pesanan, bukan durasi nyata check-in→selesai).

### 2. Detail Sesi: fokus link Zoom & catatan tutor
- `SessionHero` (mapel, tutor + foto, pil tanggal/jam/mode), `ClassAccessCard`
  (gabung Zoom sadar-waktu + hitung mundur + salin link; offline: alamat + Buka di
  Maps), `SessionNoteCard` didesain ulang (Materi / Perkembangan / blok kuning
  Tugas & saran = kolom `next_step` yang sudah ada).
- Sesi `completed` → catatan naik ke atas, kartu Zoom disembunyikan.
- Aksi jarang dipakai (ganti hari, komplain, tidak hadir) pindah ke "Opsi lain".
- **Siswa hanya bisa melihat/menyalin link saat jendela kelas dibuka** (aturan
  15 menit di `core/meeting_link.dart`); tutor kapan saja.
- `booking_summary.dart` & `zoom_join_button.dart` **dihapus**;
  `fetchBookingDetail` kini juga mengambil `tutor_catalog.photo_url`.

### 3. Profil Tutor (`/tutor/:id`)
- Gaya referensi "course details": foto besar, nama, meta Rating/Mapel/Mode,
  lalu **semua informasi dijabarkan berurutan dalam kartu (tanpa tab)** atas
  permintaan pemilik: Tentang → Mapel & jenjang → Jadwal mingguan → Ulasan siswa.
- Ulasan baru: query `reviews` (policy baca publik sudah ada), tampil **anonim**
  ("Siswa") — data siswa lain tidak dibuka. 3 ulasan + "Lihat semua". Rata-rata
  besar memakai `tutors.rating_avg`; sebaran bintang dari ≤30 ulasan terbaru.
- Tombol bawah tunggal "Beli Paket · mulai Rp…", chat pindah ke kanan atas.

### 4. Beli Paket jadi 2 langkah (logika controller TIDAK diubah)
- Langkah 1 "Atur kelas": kartu bernomor ①–⑤ yang jadi centang hijau saat terisi
  (mapel, metode, durasi, jumlah pertemuan **dengan harga tiap pilihan + label
  "Hemat"**, jadwal mingguan per hari, alamat bila tatap muka). Tombol bawah
  memberi tahu isian yang kurang, lalu "Lanjut ke ringkasan". **Tanpa total** di
  langkah 1 (permintaan pemilik; versi awal overflow karena flex 1:6).
- Langkah 2 "Ringkasan" (acuan checkout Halodoc): banner tahan slot, kartu tutor,
  Detail kelas (+ Ubah), voucher, poin, rincian biaya, bar Total + Bayar QRIS.
- Tombol back HP di langkah 2 kembali ke langkah 1 (`PopScope`).

### 5. Beranda › Kekuatan & kelemahan (grafik)
- Sumber: `student_topic_stats` (sudah diisi server tiap latihan selesai);
  `fetchMyStats` kini juga mengambil `topic_id`, `correct_count`,
  `topics(jenjang, subjects(name))`.
- **Beranda menampilkan per MAPEL, rangkuman per TOPIK** — mapel jumlahnya tetap
  sedikit & sesuai cara anak berpikir; topik = yang bisa dilatih.
- Nilai mapel = **total benar ÷ total soal** (bukan rata-rata persen topik);
  tiap batang mapel menyebut "Terlemah: <topik> <n>%" agar rata-rata tidak
  menyembunyikan topik jeblok (`home/siswa/mastery_data.dart` + tes).
- Grafik: batang horizontal 0–100% urut kuat→lemah, garis target 75%,
  3 tingkat (Kuat ≥75 hijau, Cukup 50–74 biru, Perlu latihan <50 oranye — merah
  sengaja tidak dipakai). Warna khusus grafik lolos validator buta-warna &
  kontras untuk mode terang dan gelap; selalu disertai ikon + label.
- Rangkuman: chip topik kuat + 3 topik terlemah (tombol Latihan → `/bank-soal`,
  karena pengecekan langganan ada di sana) + "Lihat grafik semua topik" →
  rute baru `/kekuatan-topik`.

### 6. Lain-lain
- `ScreenHead.eyebrow` kini opsional; label "AGENDA" dihapus dari Jadwal.
- `AppFormat.monthShort` ditambahkan.

### 7. Data dummy di Supabase ter-link (akun demo "Rani Demo")
- Foto 3 tutor demo = potret stok Unsplash (URL di `tutors.photo_url`, crop wajah).
  **Ganti dengan unggahan tutor sungguhan sebelum rilis.**
- 11 booking `completed` harga **Rp0** (bagi hasil Rp0 → tidak masuk payroll),
  masing-masing 1 ulasan + 1 catatan sesi; `rating_avg` 3 tutor dihitung ulang.
- 7 baris `student_topic_stats` (Stoikiometri 90% … Trigonometri 27%).
- Cara hapus: hapus booking milik akun demo dengan `price = 0` dan
  `status = 'completed'` (ulasan & catatan ikut terhapus via cascade), hitung
  ulang `rating_avg`, lalu hapus `student_topic_stats` milik akun demo.

## Alasan
- Struktur fitur mengikuti aturan mobile: kode bersama di `core/`, tiap fitur
  memecah layar besar ke `widgets/` / `steps/`.
- Pengelompokan, agregasi mapel, dan slot jadwal dibuat sebagai fungsi murni agar
  bisa diuji tanpa UI (`jadwal_grouping_test`, `mastery_data_test`).
- Golden `test/_preview_*` adalah alat pratinjau (font tidak termuat di tes,
  teks tampil kotak); isinya bergantung jam saat tes jalan → perlu
  `--update-goldens` bila dijalankan ulang di waktu berbeda.

## Temuan penting: tabrakan antar-sesi
Commit `c2676ee` (ganti hari dari slot tutor, sesi lain) menimpa
`booking_detail_screen.dart` dengan versi lama sehingga app gagal compile.
Sudah digabung ulang: tata letak Detail Sesi baru + `RescheduleSheet` dari commit
itu tetap jalan. **Jangan mengedit `apps/mobile` dari dua sesi bersamaan** tanpa
commit dulu.

## Langkah berikutnya
- Uji di HP: alur Jadwal 3 langkah, Detail Sesi (sesi online dekat jadwal),
  Beli Paket sampai QRIS, grafik Beranda di mode gelap.
- Tombol "Latihan" di rangkuman langsung ke `/latihan/:topicId` bila langganan
  aktif (perlu cek langganan di tombol).
- Bila ulasan sudah ratusan: hitung sebaran bintang & jumlah ulasan di backend.
- "Jam belajar" pakai durasi nyata (`checkin_at`→`completed_at`) bila diinginkan.
- Perubahan chat (`features/chat/*`) di working tree **bukan** dari sesi ini dan
  sengaja tidak ikut commit ini.
