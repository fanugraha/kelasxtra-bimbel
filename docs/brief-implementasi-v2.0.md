# Brief Implementasi — Aplikasi Layanan Bimbel
**Untuk: Claude Code (AI coding agent) — 15 Oktober 2026**
**Revisi 18 Oktober 2026**: model paket jadi pertemuan mingguan dengan harga ditetapkan admin (siswa hanya beli paket, tanpa penjualan per sesi), penjaga teks/chat & moderasi, kelas grup min 3 siswa tanpa subsidi, langganan bulanan manual + tenggang. Keputusan pemilik: `catatan/2026-10-18-model-paket-pertemuan-mingguan.md`.

Dokumen ini adalah ringkasan siap-kerja dari PRD v2.0, arsitektur teknis, dan ERD.
Detail lengkap ada di `bimbel-rancangan-produk.md` (Bagian 2 = PRD, Bagian 3 = arsitektur, Bagian 4 = ERD).
Bacalah dokumen ini dulu sampai paham, lalu mulai dari **Fase 0** dan kerjakan berurutan.

---

## 1. Ringkasan Proyek

Marketplace bimbel dengan **dua produk independen** (tidak ada ketergantungan silang):

1. **Langganan aplikasi (bank soal)** — Rp29.000/bulan, bayar via Midtrans Snap (auto-potong kartu menyusul). Latihan per topik, tryout, pembahasan, grafik skor.
2. **Paket bimbel** — privat (1-on-1) & grup (maks 5 siswa, jadwal tetap), online/offline. **Siswa hanya membeli paket 4/8/12 pertemuan** (tidak ada pembelian per sesi dari aplikasi siswa; mesin "sesi" tetap dipakai di balik layar, 1 pertemuan = 1 baris `bookings`). Bayar sekali via Midtrans Snap.
   - **Harga paket ditetapkan admin** di tabel `package_prices` (jenjang × durasi × mode × jumlah pertemuan), bukan hasil hitungan diskon.
   - **Jadwal dipilih saat membeli**: hari + jam + tanggal mulai (offline juga isi alamat). Sistem membuat **4/8/12 pertemuan mingguan** di Jadwal; slot ditahan 30 menit sampai pembayaran lunas.
   - **Masa berlaku mengikuti jumlah pertemuan**: 4 = 1 bulan, 8 = 2 bulan, 12 = 3 bulan (diperpanjang otomatis bila pertemuan terakhir jatuh lewat). Reschedule tetap **per pertemuan**.

- **Bagi hasil**: tutor 75% dari **harga sesi normal** setiap pertemuan; platform 25% + menanggung diskon paket. **Payroll tutor BULANAN oleh platform** (bukan on-demand).
- **Tutor**: freelance, direkrut internal/offline. **Admin yang buatkan akun** → tutor aktivasi via link undangan. Tidak ada pendaftaran mandiri, tidak ada upload KTP di aplikasi.
- **Siswa**: anak mendaftar sendiri, satu akun = satu siswa. Tidak ada entitas wali. Field wajib: kontak darurat (nama + no HP).
- **Offline**: khusus Jogja kota, titik kumpul di satu lokasi (rumah owner). Alamat lengkap hanya terbuka setelah pembayaran sukses.

---

## 2. Struktur Repo yang Disarankan

```
bimbel-app/
├── apps/
│   ├── mobile/                  # Flutter — SATU codebase, DUA flavor
│   │   ├── lib/
│   │   │   ├── main_siswa.dart  # entry point aplikasi siswa
│   │   │   ├── main_tutor.dart  # entry point aplikasi tutor
│   │   │   ├── core/            # supabase client, routing, theme, utils, konstan
│   │   │   ├── features/        # per fitur: auth, katalog, booking, paket,
│   │   │   │                    # bank_soal, absensi, pesan, profil, dsb.
│   │   │   └── shared/          # widget & komponen bersama
│   │   └── pubspec.yaml
│   ├── dashboard/               # Web admin (React/Vue + TypeScript)
│   │   └── src/
│   │       ├── modules/         # tutors, pricing, group-classes, monitoring,
│   │       │                    # finance, question-cms, disputes, rooms
│   │       └── ...
├── supabase/
│   ├── migrations/              # SQL versioned, JANGAN edit via dashboard di prod
│   ├── functions/               # Edge Functions (Deno)
│   └── seed.sql                 # price matrix, subjects, topics
└── docs/
    └── bimbel-rancangan-produk.md   # referensi lengkap (PRD/arsitektur/ERD)
```

---

## 3. Tech Stack

| Komponen | Pilihan |
|---|---|
| Mobile (siswa & tutor) | Flutter, state management **Riverpod**, `supabase-flutter` |
| Dashboard admin | React / Vue + TypeScript |
| Backend | **Supabase**: PostgreSQL + Auth + Storage + Edge Functions + Realtime + pg_cron |
| Pembayaran | **Midtrans**: Snap (sekali bayar + langganan bulanan manual), recurring/auto-potong menyusul, webhook notifikasi |
| Push notification | Firebase Cloud Messaging (FCM) |
| Peta/lokasi | Geolocator (Flutter) untuk check-in geofence |

---

## 4. Aturan Bisnis Kritis — JANGAN DILANGGAR

1. **Slot tutor = auto-accept.** Tidak ada tombol terima/tolak. Slot yang dibuka tutor langsung bisa dibooking.
2. **Uang = integer rupiah.** Tidak ada float. `tutor_share = floor(harga × 75 / 100)`, `platform_share = harga − tutor_share`.
3. **Harga selalu di-snapshot** ke booking/paket saat transaksi. Perubahan price matrix hanya untuk transaksi baru.
4. **Waktu simpan UTC**, tampilkan WIB (default) di UI.
5. **RLS deny-by-default.** Service role key hanya dipakai di Edge Functions, tidak pernah di client.
6. **Webhook Midtrans idempoten** by `order_id`; verifikasi signature SHA512 di server.
7. **Paket = jadwal pertemuan**: saat membeli, seluruh pertemuan mingguan dibuat sekaligus (status `pending_payment`, slot ditahan 30 menit). Webhook pembayaran hanya mengubah status (`activate_package` / `cancel_package_reservation`) sehingga idempoten dan tidak menggandakan pertemuan. Pertemuan tidak boleh melewati `expires_at`; kuota yang tidak terjadwal hangus.
8. **Komplain** dapat dibuka sampai **H+3** setelah sesi. `completed` dapat dibuka kembali → `disputed` via persetujuan CS.
9. **Auto-complete**: `in_progress` + tanpa komplain sampai H+1 → `completed` otomatis (cron).
10. **Payroll**: periode dihitung dari **tanggal jadwal sesi** (bukan tanggal completed). Cut-off tgl 25. Kalender: rekap 26 → approval 27 → transfer 28 → slip 29.
11. **Absensi**: tutor WAJIB check-in "Mulai sesi" (±15 menit). Offline: wajib dalam radius 200 m dari titik lokasi (tolak + pesan jelas bila di luar). Tanpa check-in s/d H+15 → `no_show_tutor`.
12. **Honor grup** dihitung dari kursi **terbooking** (no-show tetap dihitung).
13. **Refund <24 jam dibedakan**: privat → 50% uang kembali; pertemuan paket → 1 pertemuan hangus. >24 jam → refund penuh / pertemuan kembali utuh. Refund paket oleh admin dihitung dari **pertemuan yang belum berjalan**.
14. **Reschedule atomik**: kunci slot baru + lepas slot lama dalam satu transaksi. Tidak boleh ganti mode (online↔offline). Maks 14 hari ke depan, tidak melewati expiry paket. Counter reschedule dihitung di server.
15. **Alamat lengkap** tidak ada di API/katalog publik. Hanya dibuka untuk peserta yang sudah bayar (atau siswa yang sudah punya paket aktif). Paket offline wajib mengisi alamat saat membeli.
16. **Ledger append-only** untuk penghasilan tutor: status `belum_dibayar` → `ditahan` (komplain) → `sudah_dibayar`. Tidak ada kolom saldo yang di-update.
17. **Chat siswa↔tutor**: satu percakapan per pasangan siswa–tutor (bukan per sesi), hanya bisa dimulai setelah ada booking. Semua teks buatan pengguna (bio tutor, catatan sesi, ulasan, komplain, pesan chat) melewati **penjaga teks** yang **menolak** — bukan menyensor — konten yang membocorkan nomor HP, email, tautan, akun sosial, atau ajakan bayar di luar platform; pelanggaran dicatat di `moderation_flags` (dengan rujukan baris/percakapan) dan bisa ditindak admin (tinjau/peringatkan/tangguhkan).
18. **Satu akun = satu siswa.** Tidak ada entitas wali. Registrasi <18 tahun wajib checkbox pernyataan izin mandiri + timestamp + field kontak darurat.
19. **Voucher/promo**: 1 voucher per transaksi; validasi real-time saat checkout (aktif, belum kedaluwarsa, kuota tersedia, belum dipakai, min. pembelian); kuota dikunci saat pembayaran dimulai (race-safe), dilepas bila gagal; **diskon 100% ditanggung platform** — tutor tetap terima 75% dari **harga normal**; `voucher_id` tercatat di payment; refund penuh mengembalikan kuota per-siswa.

---

## 5. Model Data Inti (PostgreSQL/Supabase)

ERD lengkap (29 tabel) ada di Bagian 4 dokumen referensi. Tabel kunci yang harus ada sejak migrasi pertama:

| Tabel | Fungsi |
|---|---|
| `profiles` | Akun (role: student/tutor/admin + admin_role: verifikator/finance/konten/cs) |
| `students` | Profil siswa (1:1 ke profiles) + kontak_darurat |
| `tutors` | Profil tutor (status: diundang/aktif/suspend), data bank |
| `tutor_availability` | Slot ketersediaan mingguan tutor |
| `subjects`, `topics`, `levels` | Master mapel → topik, jenjang SD/SMP/SMA |
| `price_matrix` | Harga per jenjang × durasi × tipe (jadi data, bukan hardcode) |
| `package_prices` | Harga paket per jenjang × durasi × mode × jumlah pertemuan (ditetapkan admin, versi lama jadi riwayat) |
| `package_purchases` | Paket dibeli: student, tutor (terikat 1), total_sesi, schedule_day/start_time/start_date, address, price_total, expires_at, refund_amount |
| `bookings` | Satu sesi: student, tutor, jadwal (UTC), durasi, mode, harga_snapshot, status (state machine 11 status), package_purchase_id nullable, lock_expires_at |
| `booking_reschedules` | Riwayat pindah jadwal (waktu lama/baru, pengaju, alasan) |
| `group_classes` | Slot kelas grup terjadwal (tutor, kapasitas 5, ruangan) |
| `group_seats` | Kursi terbooking per siswa per kelas |
| `payments` | Transaksi Midtrans: order_id unik, tipe (booking/package/group_seat/subscription), amount, gateway_fee, status |
| `subscriptions` | Langganan bank soal (Midtrans recurring id) |
| `questions`, `question_versions` | Soal + versioning (edit tak merusak riwayat) |
| `attempts`, `attempt_answers` | Jawaban per siswa per versi soal |
| `student_topic_stats` | Agregat per siswa per topik (akurasi_20_terakhir, tren) — dibaca dashboard analisa |
| `tutor_earnings` | Ledger penghasilan per sesi (nominal_tutor, nominal_platform, status) |
| `payouts` | Rekap payroll bulanan per tutor |
| `session_notes` | Materi + progres siswa per sesi (wajib diisi tutor) |
| `reviews` | Rating & ulasan (1 per booking, maks H+3) |
| `complaints` | Tiket komplain per booking + keputusan + refund_nominal |
| `conversations`, `conversation_messages` | Chat 1 lawan 1 siswa–tutor (unik per pasangan) + tanda dibaca |
| `moderation_flags` | Catatan pelanggaran penjaga teks (jenis, potongan, rujukan baris/percakapan, status tinjau) |
| `rooms` | Master ruangan lokasi offline (anti double-booking) |
| `notifications` | Antrean notifikasi push |
| `audit_logs` | Jejak aksi sensitif (siapa, apa, kapan, sebelum/sesudah) |

Storage buckets: `avatars` (publik), `tutor-documents` — tidak dipakai di MVP (rekrutmen offline), `question-assets` (privat, soal bergambar).

---

## 6. Tahapan Implementasi

Kerjakan berurutan. Setiap fase selesai = bisa didemo sesuai acceptance criteria-nya.

### Fase 0 — Fondasi
- Setup monorepo + Supabase project (dev) + migrasi awal (profiles, students, tutors)
- Supabase Auth (email/Google), RLS deny-by-default
- CI dasar (lint + build)
- **Done jika**: registrasi/login jalan di mobile & dashboard, RLS menolak akses silang user

### Fase 1 — Akun & Profil
- Siswa daftar sendiri (checkbox izin mandiri <18 thn + kontak darurat wajib)
- Admin buat akun tutor → kirim link undangan (exp 7 hari) → tutor atur password + lengkapi profil (foto, bio) + data bank
- Suspend/reaktivasi tutor oleh admin (audit log)
- **Done jika**: alur undangan → aktivasi → profil tayang di katalog end-to-end

### Fase 2 — Katalog & Mesin Booking + Pembayaran
- Katalog tutor (filter mapel, jenjang, mode, hari tersedia, rating, urutan termurah/terbaik/A–Z; `min_price` = harga privat 60 menit termurah)
- Profil tutor + jadwal ketersediaan
- Mesin booking: pilih slot → ringkasan (harga snapshot) → Midtrans Snap → webhook (idempoten, verifikasi signature) → booking `confirmed` (auto-accept). **Siswa tidak membeli per sesi**; mesin ini dipakai paket (Fase 3) & reschedule
- Slot lock 30 menit saat pembayaran; gagal/kedaluwarsa → `expired`, slot dilepas
- Alamat lengkap terbuka pasca-bayar
- **Voucher**: input kode di ringkasan → validasi real-time → harga coret tampil (aturan #19)
- **Done jika**: transaksi berbayar sukses & gagal (termasuk timeout) tertangani benar

### Fase 3 — Paket Bimbel (hanya jalur pembelian siswa)
- Admin menetapkan harga paket di tabel `package_prices` (peringatan dashboard bila harga < 75% × harga sesi normal × jumlah pertemuan)
- Beli paket 4/8/12: pilih hari + jam + tanggal mulai (offline: alamat) → semua pertemuan mingguan dibuat & ditahan 30 menit → Snap → webhook mengaktifkan paket
- Terikat 1 tutor; masa berlaku 1/2/3 bulan mengikuti jumlah pertemuan (+ perpanjangan otomatis bila perlu)
- Reschedule per pertemuan (atomik, cek bentrok & expiry paket)
- Refund oleh admin dari pertemuan yang belum berjalan; kuota yang tidak terjadwal hangus
- **Done jika**: beli → pertemuan muncul di Jadwal → 4/8/12 pertemuan benar → refund parsial benar

### Fase 4 — Kelas Grup
- Admin buat slot grup (mapel, jenjang, jadwal, tutor, ruangan, kapasitas 5)
- Booking kursi + pembayaran per kursi; tombol nonaktif saat penuh
- Honor tutor = 75% × (harga kursi × kursi terbooking); **min 3 siswa**, tanpa subsidi. Tenggat H-1 20:00 WIB; kuota < 3 → program batal (pindah kelas/kredit, atau refund penuh)
- **Done jika**: kursi terisi ≥3 → program `confirmed`, <3 → batal & refund benar

### Fase 5 — Bank Soal + Analisis
- Langganan Rp29rb/bln via Midtrans Snap — **bulanan manual** + tenggang 3 hari; auto-potong kartu menyusul. Harga di tabel `subscription_plans`.
- CMS soal (admin konten): input + KaTeX + gambar, tag topik/level, versioning, alur draf → review → tayang
- Latihan per topik, tryout, timer opsional, pembahasan, riwayat + grafik skor
- Sistem analisis: agregat `student_topic_stats`, kategori KUAT/CUKUP/LEMAH + tren, dashboard "Fokus Perbaikimu", panel pra-sesi tutor, laporan agregat admin
- **Done jika**: langganan aktif → latihan → dashboard analisa terupdate ≤1 menit

### Fase 6 — Absensi, Reschedule, Komplain, Pesan
- Check-in tutor (geofence 200 m offline), "Saya hadir" siswa, tandai no-show, centang kehadiran grup
- Auto-complete H+1 (pg_cron); komplain s/d H+3; reopen completed → disputed via CS
- Reschedule sesuai aturan waktu (server-side, atomik, counter, tanpa ganti mode)
- Chat siswa↔tutor (lihat Fase 10)
- Kebijakan pembatalan (>24 jam penuh, <24 jam 50%/kuota hangus)
- **Done jika**: semua skenario absen/no-show/reschedule/komplain lolos uji

### Fase 7 — Payroll Bulanan
- Ledger `tutor_earnings` per sesi completed (status belum_dibayar/ditahan/sudah_dibayar)
- Rekap per tutor per periode (cut-off tgl 25 by tanggal jadwal) → four-eyes approval → ekspor daftar transfer → tombol "tandai sudah ditransfer"
- Slip penghasilan di aplikasi tutor (tanpa tombol penarikan)
- **Done jika**: simulasi 1 bulan penuh — sesi, komplain tahan, rekap, approval, tandai bayar — angka klop

### Fase 8 — Dashboard Management & Operasional
- Monitoring: progres siswa, performa tutor (jam, rating, pembatalan), operasional harian
- Laporan keuangan (gross, potongan 25%, estimasi biaya gateway)
- Kelola price matrix (riwayat perubahan), ruangan (anti double-booking), koreksi absensi (audit log)
- Migrasi paket antar-tutor (admin, atas persetujuan siswa)
- **Kelola voucher/promo**: CRUD (kode, tipe, nilai, cap, kuota, periode, produk berlaku) + laporan pemakaian (redeem, total diskon, konversi)
- **Done jika**: semua modul dashboard berfungsi dengan data nyata dari fase sebelumnya

### Fase 9 — Notifikasi & Hardening
- FCM: booking terkonfirmasi, H-1 & 1 jam sebelum sesi, pembayaran berhasil/gagal, status reschedule, payroll
- Rate limiting, audit log lengkap, backup/restore check
- Uji beban ringan + perbaikan bug
- **Done jika**: checklist go-live (di bawah) terpenuhi

### Fase 10 — Chat & Moderasi
- Satu percakapan per pasangan siswa–tutor (dimulai hanya setelah ada booking); realtime, tanda dibaca (centang satu/dua), lencana belum dibaca, notifikasi dalam aplikasi
- Penjaga teks menolak konten bocor (nomor HP/email/tautan/ajakan bayar luar) di semua teks buatan pengguna; pelanggaran tercatat `moderation_flags`
- Dashboard **Moderasi Chat**: daftar catatan, buka konteks percakapan, tandai ditinjau, kirim peringatan, tangguhkan tutor (berjejak di `audit_logs`)
- **Done jika**: chat bolak-balik realtime jalan & pelanggaran tercatat serta bisa ditindak admin

---

## 7. Konvensi Coding (wajib diikuti)

- Uang selalu `int` (rupiah). Jangan pakai float/double untuk uang.
- Waktu: simpan UTC (`timestamptz`), tampilkan zona pengguna (default WIB).
- RLS: tolak semua secara default; buka per kebutuhan. Jangan query dengan service role dari client.
- Setiap fungsi yang menyentuh uang harus **idempoten** (aman dipanggil ulang).
- Harga tidak pernah dihitung ulang dari matrix untuk transaksi lama — selalu pakai snapshot.
- Semua aksi sensitif (payout, refund, koreksi absensi, suspend) tulis ke `audit_logs`.
- Migration SQL harus versioned & bisa di-rollback; jangan ubah skema via dashboard di production.

---

## 8. Yang TIDAK Dibangun (out of scope)

Tier OSN + badge tutor OSN · akun orang tua · gamifikasi/leaderboard · waitlist kelas grup · tutor membuat slot grup sendiri · analitik LTV lanjutan · langganan per mapel · upload dokumen tutor (KTP/ijazah) · tombol terima/tolak booking · tombol penarikan dana tutor · penjualan per sesi (siswa hanya beli paket) · FCM/notifikasi HP (ditunda; kini notifikasi dalam aplikasi).

---

## 9. Checklist Go-Live (MVP)

- [ ] Seluruh fase 0–10 selesai + didemo
- [ ] Rekonsiliasi: total Midtrans settlement = total payments tercatat
- [ ] Simulasi payroll 1 bulan angka klop (termasuk 1 kasus komplain & 1 no-show)
- [ ] RLS diuji: siswa A tidak bisa baca data siswa B; tutor hanya lihat siswanya sendiri
- [ ] Webhook Midtrans: sukses, gagal, duplikat (idempotency) teruji
- [ ] Konsultasi hukum (regulasi penahanan dana) & akuntan (pajak tutor) selesai
- [ ] SOP operasional (keselamatan lokasi, kalender payroll, SLA) disosialisasikan ke tim
- [ ] Keputusan terbuka O1–O8 sudah diputus management

---

*Dokumen referensi penuh: `bimbel-rancangan-produk.md` (Bagian 2 = PRD v2.0, Bagian 3 = arsitektur teknis, Bagian 4 = ERD 29 tabel). Jika ada konflik antara brief ini dan dokumen referensi, dokumen referensi yang menang.*
