# Bank Soal: navigasi per mapel, paket coba gratis, layar mengerjakan soal, simbol rumus (19 Okt 2026)

## Konteks
Lanjutan sesi Claude Code (lihat catatan `2026-10-19-rombak-ux-jadwal-sesi-paket-kekuatan`).
Pemilik meminta: (1) Bank Soal yang memudahkan siswa berpindah antar mapel, wajib
langganan, tapi ada **1 paket soal gratis 10 soal Matematika** untuk mencoba;
(2) layar mengerjakan soal yang mudah dinavigasi dan **semua simbol MTK/Fisika/Kimia
terbaca**; (3) Beranda: "Jadwal berikutnya" pindah ke urutan 2 dan karusel promo
bergeser otomatis.

## Keputusan atau temuan

### 1. Backend: paket soal + paket gratis (migrasi `20261019000048_paket_soal_gratis.sql`)
- Tabel baru `question_packs` (judul, mapel, topik, jenjang, `is_free`, `active`) dan
  `question_pack_items` (urutan soal tetap). Kolom baru `attempts.pack_id`.
- RPC baru (security definer, `execute` dicabut dari `anon` eksplisit):
  - `start_pack_attempt(p_pack)` — paket `is_free` boleh tanpa langganan; paket
    lain tetap wajib `has_active_subscription`. Penilaian tetap `submit_attempt`
    (statistik topik ikut terisi → grafik kekuatan Beranda ikut berubah).
  - `bank_soal_catalog()` — topik aktif + jumlah soal terbit (siswa tidak boleh
    membaca tabel `questions`).
  - `my_question_packs()` — paket aktif + jumlah soal + nilai terakhir siswa.
- `start_attempt` (latihan per topik) **tidak diubah** → tetap wajib langganan.
- Isi: **5 soal Trigonometri SMA baru** (sin 45°, cos 0°, sin A = 3/5 → cos A,
  sin 30° + cos 60°, cos 120°) + 5 soal lama → paket "Paket Coba Gratis:
  Trigonometri" berisi 10 soal.
- **Diterapkan dengan `supabase db query --linked -f`**, BUKAN `db push` (lihat
  catatan jebakan migrasi), lalu dicatat manual di
  `supabase_migrations.schema_migrations` versi `20261019232222`
  (`paket_soal_gratis`).
- Diuji sebagai akun demo tanpa langganan (dalam transaksi yang di-rollback):
  paket gratis bisa dimulai (10 soal), latihan per topik ditolak
  "Langganan tidak aktif".
- Catatan: paket gratis bisa diulang tanpa batas; belum ada UI admin untuk paket.

### 2. Halaman Bank Soal (`bank_soal_screen.dart` ditulis ulang)
- Urutan: (belum langganan) kartu **Coba gratis** + kartu langganan berisi manfaat
  & harga; (sudah) satu baris status + Perpanjang → **navigator mapel** (jenjang
  SMP/SMA mengikuti profil + chip mapel bisa digeser) → **panel topik mapel
  terpilih** (jumlah soal, nilai siswa pakai warna Kuat/Cukup/Perlu latihan,
  tombol ▶ atau 🔒) → kartu Tryout.
- Topik terkunci tetap bisa diketuk → lembar penjelasan + 2 jalan keluar
  (Langganan / Coba gratis). Tidak ada tombol mati tanpa penjelasan.
- "Fokus perbaikan" dihapus dari Bank Soal (sudah ada di Beranda).
- `stats_list.dart`, `topics_list.dart`, `topicsProvider`, `fetchTopics` dihapus.
- `Mastery` (tingkat & warna penguasaan) dipindah ke `core/mastery.dart` karena
  kini dipakai 2 fitur (Beranda & Bank Soal).
- Rute baru `/paket-soal/:id` → `LatihanScreen(packId: …)`.

### 3. Layar mengerjakan soal (`latihan_screen.dart` ditulis ulang)
- Bar atas: ✕ keluar (konfirmasi), nama topik, "Soal n dari N", timer tryout
  (oranye di menit terakhir), tombol **Daftar soal** (`answered/total`).
- **Strip progres per nomor** (dijawab/ragu/belum; ketuk untuk lompat) dan
  lembar **Daftar soal** berupa kisi nomor + legenda (`widgets/question_navigator.dart`).
- Tanda **Ragu-ragu** (gaya UNBK); boleh melewati soal ("Lewati"/"Berikutnya");
  soal terakhir → "Selesai". Konfirmasi sebelum dinilai menyebut jumlah soal
  kosong & ragu.
- **Gambar soal kini ditampilkan** (sebelumnya tidak pernah) lewat
  `signedImageUrl`, bisa diketuk untuk diperbesar.
- Pilihan jawaban = kartu besar (min. 58px), huruf dalam lingkaran.
- `HasilScreen` kini menerima `answers`: nilai + Benar/Salah/Kosong, filter
  "Salah saja", tiap soal menampilkan semua pilihan (benar hijau, pilihan siswa
  yang salah merah) + pembahasan.

### 4. Renderer rumus (`widgets/math_text.dart`)
- Teks & rumus kini mengalir dalam satu paragraf (`Text.rich` + `WidgetSpan`),
  bukan kotak-kotak dalam `Wrap`.
- Logika dipisah ke fungsi murni `mathParts()`; bila TeX gagal di-parse yang tampil
  teks asli (`onErrorFallback`), bukan error merah.
- Baru: rumus kimia umum (`H2SO4`, `Ca(OH)2`, `C6H12O6` → indeks bawah; sebelumnya
  hanya CO/NO/SO), pecahan bersusun (`1/2`, `akar3/2`, `22/7`), pecahan berkurung
  `(x^2 - 4)/(x - 2)`, satuan tegak (`0,5 mol`, `5 m/s^2`), `->` `>=` `<=` `!=`.
- **Tes menjamin semua teks soal terbaca**: `test/fixtures/question_texts.json`
  (287 teks soal/opsi/pembahasan yang terbit, diekspor dari DB — konten soal saja)
  dan `math_text_test.dart` mem-parse SETIAP potongan TeX dengan `TexParser`.
  **Perbarui fixture bila soal baru ditambahkan** agar notasi baru ikut teruji.

### 5. Beranda
- Urutan siswa: Promo → **Jadwal berikutnya** → Kekuatan & kelemahan → Tutor pilihan.
- `PromoCarousel` bergeser otomatis tiap 4 detik lalu kembali ke awal; diulang
  dari awal saat siswa menggeser sendiri, berhenti saat tab tersembunyi
  (`TickerMode`) dan saat animasi dimatikan di pengaturan HP (+ tes).

## Alasan
- Paket berurutan tetap (bukan acak) agar pengalaman coba gratis konsisten dan
  bisa dibandingkan saat diulang; aturan akses di server, bukan di app.
- Mapel sebagai navigasi utama karena jumlahnya sedikit & dikenali anak; topik
  di dalam kartu mapel.

## Temuan penting: kerja paralel dengan sesi lain
- Saat commit ini, **sesi lain sedang mengubah tema** (`core/theme/app_colors.dart`,
  `app_palette.dart`, `app_theme.dart` — palet gelap arang + periwinkle) dan sudah
  memperbarui 5 golden lama untuk tema itu. File-file itu **sengaja tidak ikut**
  commit ini; commit sendiri bersama goldennya.
- Golden `test/_preview_*` bergantung jam & tema; perbarui dengan
  `--update-goldens` setelah tema final.

## Langkah berikutnya
- Uji di HP: Bank Soal (akun belum langganan → coba gratis → hasil), latihan per
  topik dengan langganan aktif, tryout + timer, gambar soal.
- Dashboard admin: CRUD `question_packs` / `question_pack_items`.
- Opsional: batasi paket gratis (mis. 1× per siswa) di `start_pack_attempt`.
- Tombol "Latihan" di rangkuman Beranda bisa langsung ke `/latihan/:topicId` bila
  langganan aktif.
