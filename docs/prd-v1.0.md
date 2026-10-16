# PRD — Aplikasi Layanan Bimbel

| | |
|---|---|
| **Dokumen** | Product Requirements Document |
| **Versi** | 1.0 — 15 Oktober 2026 |
| **Status** | Draf hasil diskusi, siap jadi acuan development |
| **Dokumen terkait** | `bimbel-mvp-fitur.md` (daftar fitur MVP) |

---

## 1. Latar Belakang & Masalah

Orang tua di Jogja yang mencari bimbel untuk anaknya hari ini menghadapi tiga masalah:

1. **Sulit menilai kualitas tutor privat.** Tutor freelance bertebaran di media sosial dan marketplace umum tanpa verifikasi latar belakang, tanpa rekam jejak mengajar, dan tanpa mekanisme komplain yang jelas — padahal yang diajar adalah anak di bawah umur.
2. **Progres belajar tidak terpantau.** Setelah membayar, orang tua tidak tahu apakah nilai anak membaik, tutor datang tepat waktu, atau materi benar-benar tersampaikan. Bimbel konvensional jarang memberi laporan yang transparan.
3. **Akses latihan soal terbatas.** Bank soal yang terkurasi per topik dan tryout dengan pembahasan umumnya terkunci di paket bimbel mahal, tidak bisa dibeli terpisah dengan harga terjangkau.

Dari sisi penyedia, tutor freelance yang kompeten kesulitan mendapatkan siswa secara konsisten dan tidak punya sistem administrasi (jadwal, pembayaran, riwayat mengajar). Sementara pengelola bimbel yang beroperasi secara manual (chat, spreadsheet, transfer manual) tidak punya visibilitas atas progres siswa, performa tutor, dan arus kas secara real-time.

**Produk ini** adalah platform bimbel marketplace dengan **dua produk yang independen**:
1. **Langganan aplikasi** — akses bank soal (latihan per topik, tryout, pembahasan) seharga Rp29.000/bulan via Midtrans recurring.
2. **Paket sesi bimbel** — privat maupun grup kecil (maks 5 siswa) dari tutor freelance terverifikasi, **dijual terpisah** per paket (4/8/12 sesi) dan dibayar sekali bayar via Midtrans Snap. Pembelian paket **tidak mensyaratkan** langganan bank soal aktif, dan sebaliknya.

Layanan tersedia online maupun offline (offline khusus area Jogja kota). Management memantau seluruh operasional lewat web dashboard.

---

## 2. Tujuan Produk

1. Menjadi platform bimbel tepercaya di Jogja dengan standar verifikasi tutor dan transparansi progres belajar.
2. Memberi tutor freelance kanal pendapatan yang adil (bagi hasil 75%) dengan administrasi otomatis.
3. Memberi management visibilitas penuh: progres tiap siswa, performa tiap tutor, dan kesehatan operasional/keuangan dalam satu dashboard.
4. Mencapai unit ekonomi yang sehat: margin platform 25% per transaksi + recurring revenue dari langganan bank soal.

---

## 3. Persona Pengguna

### 3.1. Siswa — "Nadia", 14 tahun, SMP kelas 8
Belajar matematika untuk persiapan ujian. Butuh latihan soal yang banyak dengan pembahasan, dan kadang butuh guru privat saat mentok. Memakai HP Android milik sendiri, tapi yang membayar adalah orang tuanya.

### 3.2. Orang Tua / Wali — "Bu Ratna", ibu Nadia
Yang memutuskan dan membayar. Prioritasnya: tutor yang aman dan terverifikasi, tahu perkembangan nilai anak, dan tidak ribet soal pembayaran. Butuh kepastian bahwa anaknya belajar di tempat yang jelas.

### 3.3. Tutor Freelance — "Mas Dimas", 23 tahun, mahasiswa S2
Mengajar matematika SMP/SMA untuk menambah penghasilan. Butuh aliran siswa yang stabil, jadwal yang bisa ia atur sendiri, dan pembayaran yang transparan dan tepat waktu. Bersedia diverifikasi (KTP, ijazah) demi mendapat badge kepercayaan.

### 3.4. Admin Management — "Tim Operasional Bimbel"
Bertanggung jawab atas kualitas layanan dan kelangsungan bisnis. Butuh: memverifikasi tutor baru, mengatur harga dan jadwal kelas grup, memantau progres siswa dan performa tutor, mengelola keuangan dan payout, serta menangani komplain.

> Catatan: di MVP, peran orang tua belum dipisah menjadi akun tersendiri — satu akun siswa mencakup data wali (nama, kontak, persetujuan). Akun orang tua terpisah masuk Fase 2.

---

## 4. Ruang Lingkup

### 4.1. In Scope (MVP)

**Aplikasi Siswa (mobile):**
- Registrasi/login + data siswa & wali
- Katalog & profil tutor (filter mapel, jenjang, harga, rating; badge terverifikasi)
- Booking sesi privat: pilih tutor → jadwal → durasi (60/90/120 menit) → mode online/offline → pembayaran Midtrans
- Kelas grup: jadwal tetap, info sisa kursi (maks 5), booking kursi, pembayaran
- Pembelian paket sesi: 4 sesi (harga normal), 8 sesi (−5%), 12 sesi (−10%)
- Bank soal: langganan Rp29.000/bulan (Midtrans recurring), latihan per topik, tryout, riwayat & grafik skor
- Jadwalku & riwayat belajar
- Rating & ulasan tutor pasca-sesi
- Notifikasi: konfirmasi booking, pengingat jadwal, status pembayaran

**Aplikasi Tutor (mobile):**
- Pendaftaran + upload dokumen (KTP, ijazah/sertifikat) + status verifikasi
- Pengaturan jadwal ketersediaan mingguan
- Terima/tolak permintaan sesi privat; daftar jadwal mengajar (privat + grup)
- Catatan sesi: materi yang diajarkan + progres siswa
- Dompet penghasilan (75% per sesi), riwayat, pengajuan penarikan
- Rating & ulasan dari siswa

**Dashboard Management (web):**
- Verifikasi tutor (setujui/tolak + alasan)
- Kelola price matrix (per jenjang × durasi × tipe layanan)
- Kelola kelas grup: buat slot jadwal, assign tutor, pantau keterisian
- Monitoring siswa (kehadiran, skor tryout), tutor (jam mengajar, rating, catatan sesi), operasional (jadwal hari ini, booking masuk)
- Laporan keuangan: pemasukan, potongan platform 25%, estimasi biaya gateway Midtrans
- Persetujuan & eksekusi payout tutor
- CMS bank soal: input soal + pembahasan, tag mapel/topik/tingkat kesulitan, alur review sebelum tayang
- Penanganan komplain/sengketa (pembatalan, no-show, refund)

### 4.2. Out of Scope → Fase 2
- Tier OSN / pendampingan lomba + badge "Tutor OSN" (struktur harga sudah final, tinggal diaktifkan)
- Akun orang tua terpisah dengan kontrol & laporan khusus
- Gamifikasi (leaderboard, badge siswa, streak)
- Voucher / kode promo
- Waitlist kelas grup yang penuh
- Chat in-app (MVP: tombol hubungi via WhatsApp)
- Tutor membuat/mengusulkan slot kelas grup sendiri
- Analitik lanjutan (retensi, LTV, segmentasi)

---

## 5. User Stories

### 5.1. Siswa / Orang Tua

| ID | User Story | Acceptance Criteria |
|---|---|---|
| US-S1 | Sebagai siswa, saya ingin mendaftar akun dengan data diri dan wali, agar saya bisa membeli layanan dan orang tua saya tercatat sebagai penanggung jawab | Registrasi email/Google berhasil; wajib isi nama siswa, jenjang, nama & kontak wali; wali dianggap menyetujui untuk siswa < 18 tahun |
| US-S2 | Sebagai siswa, saya ingin mencari tutor berdasarkan mapel, jenjang, dan harga, agar saya menemukan tutor yang sesuai kebutuhan dan budget | Filter mapel + jenjang + rentang harga + rating minimum berfungsi; hasil menampilkan foto, nama, rating, tarif |
| US-S3 | Sebagai orang tua, saya ingin melihat profil tutor lengkap dengan badge verifikasi dan ulasan, agar saya yakin anak saya diajar orang yang tepat | Profil menampilkan badge "Terverifikasi", riwayat pendidikan, mapel yang diajar, rating rata-rata, daftar ulasan, jadwal tersedia |
| US-S4 | Sebagai siswa, saya ingin memesan sesi privat (pilih jadwal, durasi, online/offline) dan membayar via Midtrans, agar sesi saya terjadwal resmi | Alur: pilih slot tersedia → ringkasan biaya → bayar via Midtrans Snap → status booking "terkonfirmasi"; slot tidak bisa dipesan ganda |
| US-S5 | Sebagai siswa, saya ingin alamat lengkap lokasi offline baru terlihat setelah pembayaran berhasil, agar privasi lokasi terjaga | Sebelum bayar: tampil "Jogja Kota" saja; setelah bayar: alamat lengkap + petunjuk lokasi terbuka |
| US-S6 | Sebagai siswa, saya ingin membeli paket 8/12 sesi dengan diskon otomatis, agar lebih hemat dibanding beli satuan | Harga paket dihitung otomatis (total − 5%/10%); sisa kuota sesi paket terlihat dan berkurang tiap booking; pembelian paket tidak mensyaratkan langganan bank soal |
| US-S7 | Sebagai siswa, saya ingin melihat kelas grup yang tersedia beserta sisa kursinya, agar saya bisa ikut kelas yang masih ada tempat | Daftar kelas grup (mapel, jenjang, jadwal, tutor, sisa kursi x/5); tombol booking nonaktif saat penuh |
| US-S8 | Sebagai siswa, saya ingin berlangganan bank soal bulanan dan berhenti kapan saja, agar saya bisa latihan mandiri dengan biaya terjangkau | Langganan Rp29.000/bulan via Midtrans recurring; akses latihan & tryout aktif selama langganan; bisa berhenti, akses berakhir di akhir periode |
| US-S9 | Sebagai siswa, saya ingin mengerjakan latihan per topik dan tryout lalu melihat skor serta pembahasannya, agar saya tahu kelemahan saya | Soal tampil per topik dengan timer opsional; skor + pembahasan muncul setelah selesai; riwayat skor tersimpan dengan grafik perkembangan |
| US-S10 | Sebagai siswa, saya ingin memberi rating dan ulasan ke tutor setelah sesi, agar tutor berkualitas mendapat reputasi yang pantas | Form rating (1–5) + ulasan wajib diisi maksimal H+3 setelah sesi; satu rating per sesi; memengaruhi rating rata-rata tutor |
| US-S11 | Sebagai siswa, saya ingin diingatkan jadwal sesi dan status pembayaran via notifikasi, agar tidak lupa atau salah jadwal | Push notifikasi: booking terkonfirmasi, H-1 & 1 jam sebelum sesi, pembayaran berhasil/gagal |

### 5.2. Tutor

| ID | User Story | Acceptance Criteria |
|---|---|---|
| US-T1 | Sebagai calon tutor, saya ingin mendaftar dan mengunggah KTP + ijazah, agar saya bisa diverifikasi dan mulai mengajar | Upload KTP & ijazah (format umum, maks 5 MB) tersimpan aman; status awal "menunggu verifikasi"; profil belum tayang ke siswa |
| US-T2 | Sebagai tutor, saya ingin mengatur jadwal ketersediaan mingguan saya, agar siswa hanya bisa booking di waktu saya luang | Grid ketersediaan per hari-jam bisa diubah; slot yang sudah dibooking tidak bisa dihapus; perubahan berlaku untuk booking baru |
| US-T3 | Sebagai tutor, saya ingin menerima atau menolak permintaan sesi privat, agar saya memegang kendali atas jadwal saya | Notifikasi permintaan masuk; batas respons (misal 12 jam); penolakan tidak dikenai penalti di MVP; slot kembali tersedia |
| US-T4 | Sebagai tutor, saya ingin melihat seluruh jadwal mengajar saya (privat + grup), agar saya tidak bentrok | Kalender/agenda gabungan; detail tiap sesi (siswa, mapel, mode, lokasi/link); pengingat H-1 |
| US-T5 | Sebagai tutor, saya ingin mencatat materi dan progres siswa setiap selesai sesi, agar management dan orang tua bisa memantau perkembangan | Form wajib pasca-sesi: materi diajarkan + catatan progres; tersimpan di riwayat siswa; bisa dibaca management |
| US-T6 | Sebagai tutor, saya ingin melihat penghasilan saya (75% per sesi terkonfirmasi) dan mengajukan penarikan, agar pendapatan saya transparan | Dompet menampilkan saldo, riwayat per sesi (tanggal, siswa, nominal 75%); tombol ajukan penarikan; status penarikan terlacak |
| US-T7 | Sebagai tutor, saya ingin melihat rating dan ulasan dari siswa, agar saya tahu apa yang perlu diperbaiki | Daftar ulasan per sesi; rating rata-rata; notifikasi saat ada ulasan baru |

### 5.3. Management

| ID | User Story | Acceptance Criteria |
|---|---|---|
| US-M1 | Sebagai admin, saya ingin meninjau dokumen calon tutor dan menyetujui/menolaknya, agar hanya tutor layak yang tayang | Antrean verifikasi dengan pratinjau dokumen; aksi setujui/tolak + alasan; penolakan mengirim notifikasi ke tutor |
| US-M2 | Sebagai admin, saya ingin mengubah daftar harga (per jenjang × durasi × tipe), agar penyesuaian bisnis tidak butuh rilis aplikasi | Price matrix dapat diubah via dashboard; berlaku untuk booking baru; riwayat perubahan tercatat |
| US-M3 | Sebagai admin, saya ingin membuat slot kelas grup dan menugaskan tutor, agar penawaran kelas grup selalu tersedia | Form: mapel, jenjang, jadwal, durasi, tutor, kapasitas 5; slot tayang ke katalog siswa; keterisian terpantau real-time |
| US-M4 | Sebagai admin, saya ingin memantau progres tiap siswa (kehadiran, skor tryout), agar saya bisa intervensi jika ada yang tertinggal | Dasbor per siswa: kehadiran, grafik skor, catatan tutor; filter siswa dengan tren menurun |
| US-M5 | Sebagai admin, saya ingin memantau performa tutor (jam mengajar, rating), agar kualitas pengajaran terjaga | Dasbor per tutor: total jam, jumlah sesi, rating rata-rata, riwayat catatan sesi; penanda tutor berating rendah |
| US-M6 | Sebagai admin, saya ingin melihat laporan keuangan (pemasukan, potongan 25%, biaya gateway), agar angka bisnis jujur dan terpantau | Laporan per periode: gross, potongan platform, estimasi biaya Midtrans, payout tutor; dapat diekspor |
| US-M7 | Sebagai admin, saya ingin menyetujui penarikan dana tutor, agar arus kas terkendali | Antrean penarikan dengan nominal & rekening tujuan; aksi setujui/tolak; status tercatat di riwayat tutor |
| US-M8 | Sebagai admin konten, saya ingin menginput soal + pembahasan dengan tag dan alur review, agar bank soal berkualitas sebelum tayang | Form soal (pilihan ganda), pembahasan, tag mapel/topik/level; status draf → review → tayang; soal tayang otomatis masuk bank soal |
| US-M9 | Sebagai admin, saya ingin menangani komplain (pembatalan/no-show) dan mengeksekusi refund, agar sengketa selesai adil | Tiket komplain per booking; riwayat komunikasi; aksi refund penuh/sebagian sesuai kebijakan; kedua pihak ternotifikasi |

---

## 6. Alur Utama

### 6.1. Booking & Pembayaran Sesi

```
Siswa                          Sistem                        Tutor / Midtrans
  |                               |                                |
  |-- cari tutor/kelas grup ------>|                                |
  |<-- daftar + slot tersedia -----|                                |
  |-- pilih slot & durasi -------->|                                |
  |<-- ringkasan biaya -----------|                                |
  |-- bayar --------------------->|-- Midtrans Snap -------------->|
  |                               |<-- callback sukses/gagal ------|
  |<-- booking terkonfirmasi ------|--- notif ke tutor ------------>|
  |                               |                                |
  |         ... sesi berlangsung (online via link / offline di lokasi) ...
  |                               |                                |
  |-- konfirmasi selesai --------->|<-- tutor isi catatan sesi -----|
  |                               |-- dana 75% masuk dompet tutor  |
  |<-- diminta rating tutor -------|                                |
```

Aturan penting:
- Slot yang sudah dibayar tidak dapat dipesan pihak lain (kunci slot saat pembayaran dimulai, lepas jika gagal/kedaluwarsa).
- Alamat lengkap lokasi offline hanya terbuka setelah pembayaran sukses.
- Dana masuk dompet tutor hanya setelah **kedua pihak konfirmasi** sesi selesai (atau otomatis H+1 jika tidak ada komplain — menunggu keputusan kebijakan).

### 6.2. Langganan Bank Soal

```
Siswa -- pilih langganan Rp29rb/bln --> Midtrans recurring --> aktif
  |-- latihan per topik / tryout --> skor + pembahasan --> grafik progres
  |-- berhenti langganan --> akses hingga akhir periode --> nonaktif
```

- Pembayaran pertama: Snap; perpanjangan: Midtrans recurring (auto-debit kartu).
- Jika auto-debit gagal: masa tenggang (usul: 3 hari) dengan notifikasi, lalu akses dikunci sampai bayar.

### 6.3. Payout Tutor

```
Sesi terkonfirmasi --> saldo 75% masuk dompet tutor
Tutor -- ajukan penarikan --> Admin review --> setujui --> transfer manual/otomatis
                                          \-> tolak + alasan --> tutor ternotifikasi
```

### 6.4. Onboarding & Verifikasi Tutor

```
Daftar akun --> lengkapi profil + upload KTP & ijazah --> status MENUNGGU
Admin review dokumen --> SETUJU --> profil tayang, bisa terima sesi
                     \-> TOLAK + alasan --> tutor dapat notifikasi, bisa ajukan ulang
```

### 6.5. Penanganan Komplain

```
Siswa/tutor -- buat komplain (pilih booking) --> tiket masuk antrean admin
Admin -- mediasi via riwayat chat/komunikasi --> putuskan:
   |-- sesi tetap valid --> dana cair normal
   |-- refund penuh / sebagian --> eksekusi via Midtrans --> kedua pihak ternotifikasi
```

---

## 7. Kebutuhan Non-Fungsional

| Kategori | Kebutuhan |
|---|---|
| **Keamanan data anak** | Data siswa di bawah umur diperlakukan sebagai data sensitif: akses dibatasi per peran (tutor hanya melihat data siswa yang ia ajar; tidak ada ekspor massal); persetujuan wali tercatat saat registrasi |
| **Privasi alamat** | Alamat lengkap titik kumpul offline tidak tampil di katalog publik; hanya dibuka untuk peserta yang sudah bayar; tidak boleh di-cache/di-screenshot-prevent? (minimal: tidak tampil di API publik) |
| **Keamanan dokumen tutor** | KTP & ijazah disimpan di storage privat (signed URL berumur pendek), hanya bisa diakses admin verifikasi |
| **Keamanan pembayaran** | Verifikasi signature callback Midtrans di sisi server; idempotency untuk webhook; tidak menyimpan data kartu |
| **Performa** | Waktu buka katalog & profil tutor < 3 detik di jaringan 4G; pencarian/filter responsif (< 1 detik untuk hasil awal) |
| **Ketersediaan** | Target 99,5% uptime layanan inti (booking, pembayaran); maintenance terjadwal di luar jam ramai (malam hari) |
| **Skalabilitas awal** | Arsitektur harus tahan 10x lipat pengguna tanpa tulis ulang (antisipasi fase 2 & ekspansi kota) |
| **Audit** | Semua aksi sensitif tercatat: verifikasi tutor, perubahan harga, approve payout, refund |

---

## 8. Metrik Kesuksesan (KPI)

### Fase MVP (0–6 bulan)
| Metrik | Target awal (usul) |
|---|---|
| Tutor terverifikasi aktif | ≥ 20 tutor |
| Siswa terdaftar | ≥ 200 siswa |
| Tingkat penyelesaian sesi (tanpa komplain) | ≥ 95% |
| Rating rata-rata tutor | ≥ 4,5 / 5 |
| Pelanggan bank soal berbayar | ≥ 100 pelanggan |
| Waktu verifikasi tutor (daftar → tayang) | ≤ 3 hari kerja |

### Fase 2 (6–12 bulan)
| Metrik | Target awal (usul) |
|---|---|
| Retensi langganan bank soal (bulanan) | ≥ 70% |
| Repeat booking (siswa beli paket ke-2) | ≥ 40% |
| Tutor aktif bulanan | ≥ 50 tutor |
| Komplain per 100 sesi | < 3 |
| Aktivasi tier OSN | ≥ 5 tutor OSN, ≥ 30 sesi/bulan |

> Target angka bersifat usulan — ditetapkan final oleh management sebelum development.

---

## 9. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Tutor berperilaku tidak pantas ke siswa di bawah umur | Fatal — reputasi & hukum | Verifikasi KTP + ijazah wajib; sesi offline di ruang bersama/terpantau; sistem rating & pelaporan; suspend cepat + investigasi |
| Tutor no-show / siswa no-show | Kecewa, refund, operasional | Kebijakan pembatalan tertulis; denda/pinalti; riwayat kehadiran memengaruhi visibilitas tutor di katalog |
| Sengketa "sesi tidak terjadi" | Dana nyangkut, kepercayaan turun | Konfirmasi dua pihak + catatan sesi wajib; mediasi admin; aturan refund jelas sejak awal |
| Kebocoran alamat rumah owner | Privasi & keamanan pribadi | Alamat hanya untuk peserta berbayar; tampilkan area umum ("Jogja Kota") di katalog; edukasi tutor |
| Tutor membawa siswa transaksi di luar platform | Pendapatan bocor | Insentif tetap di platform (reputasi, jadwal, payout mudah); klausul kemitraan; deteksi pola anomali |
| Kegagalan pembayaran / webhook Midtrans | Booking gantung | Idempotency + rekonsiliasi berkala; status booking "menunggu pembayaran" dengan batas waktu; retry notifikasi |
| Bank soal lambat terisi (konten internal) | Produk langganan tidak menarik | Target produksi soal per minggu; alur review ringan; prioritaskan topik ujian populer dulu |
| Kapasitas rumah terbatas (offline) | Antrean, siswa kecewa | Slot grup terjadwal + batas 5 orang; dorong mode online (lebih murah Rp10rb); roadmap sewa/pindah lokasi |

---

## 10. Asumsi & Keputusan Terbuka

### Asumsi yang dipakai
1. Satu akun siswa mencakup persetujuan wali (akun orang tua terpisah = fase 2).
2. Kelas grup berjalan dengan **jadwal tetap** yang dibuat management; tidak ada pembentukan grup on-demand di MVP.
3. Tarif mengikuti price matrix final (terlampir di `bimbel-mvp-fitur.md`); perubahan harga via dashboard tanpa rilis aplikasi.
4. OSN adalah tier fase 2 — skema harga sudah final, tinggal aktivasi.
5. Komunikasi siswa–tutor di MVP via WhatsApp (deep link), bukan chat in-app.
6. Midtrans menanggung ~2–3% biaya gateway per transaksi (dilaporkan terpisah, tidak memotong bagi hasil tutor).

### Keputusan yang masih terbuka
| # | Keputusan | Opsi | Dampak jika belum diputus |
|---|---|---|---|
| 1 | Minimal peserta kelas grup | Tetap jalan / batal & reschedule / gabung ke slot lain | Menentukan logika booking & refund otomatis |
| 2 | Kebijakan pembatalan | Misal batal H-1: potongan 50%? no-show tutor: sesi gratis pengganti? | Menentukan alur komplain & refund |
| 3 | Siklus payout tutor | Kapan saja / mingguan / bulanan | Menentukan desain dompet & beban admin |
| 4 | Pembulatan bagi hasil 75/25 | Eksak (misal Rp44.250) / bulatkan ke Rp500 | Menentukan perhitungan dompet & laporan |
| 5 | Konfirmasi penyelesaian sesi | Dua pihak wajib / otomatis H+1 tanpa komplain | Menentukan kapan dana cair ke tutor |
| 6 | Masa tenggang langganan gagal bayar | Usul 3 hari | Menentukan logika penguncian akses bank soal |

---

*Dokumen ini adalah acuan hidup — perbarui setiap kali ada keputusan baru dari diskusi.*


