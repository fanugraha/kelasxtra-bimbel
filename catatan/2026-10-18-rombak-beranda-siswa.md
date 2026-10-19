# Rombak Beranda siswa (18 Okt 2026)

## Konteks

Pemilik menilai Beranda siswa belum rapi: margin atas/samping tidak enak dilihat, kartu promo
berantakan, dan kartu tutor terlalu minim (tanpa harga & hari tersedia). Pemilik minta riset UX/UI
dulu sebelum diubah.

## Keputusan atau temuan

- **Aturan harga di kartu tutor (pilihan pemilik):** "mulai dari" = harga **privat 60 menit**
  termurah untuk jenjang + mode yang tersedia milik tutor. Bukan harga grup (bisa menyesatkan).
- **Cakupan:** Beranda siswa saja; widget kartu dibuat reusable agar nanti bisa dipakai Katalog.
- **Data ringkasan ditaruh di view**, bukan query tambahan dari aplikasi: migrasi
  `20261018000037_tutor_catalog_ringkas.sql` menambah kolom `subjects`, `jenjang`, `days`,
  `modes`, `min_price` di `public.tutor_catalog`.
  - `CREATE OR REPLACE VIEW` hanya boleh menambah kolom di akhir; kolom ringkasan ditaruh
    setelah `created_at`.
  - `string_agg(distinct …, order by <ekspresi>)` ditolak Postgres (42P10) bila ekspresi
    urutnya bukan argumen; untuk urutan SD→SMP→SMA dipakai subquery `distinct` + `order by ord`.
  - Hari diambil dari `tutor_availability` yang `active`; harga dari `price_matrix` `active`
    (`type='privat'`, `duration_minutes=60`) dengan mode mengikuti jadwal tutor (kalau tutor
    belum punya jadwal, mode apa pun dihitung).
- **Ritme jarak Beranda** kini memakai token `AppSpacing`: kepala→isi 16, antar bagian 24,
  judul bagian→isi 12, ruang atas kepala layar 8 (dulu angka lepas 18/22/9/14).
- **Kartu promo:** tinggi 154, radius `AppRadius.lg`, ikon di sisi kanan kicker, judul maks 2
  baris, aksi jadi pil (bukan teks kecil), indikator halaman berupa pil.
- **Kartu tutor baru** `apps/mobile/lib/widgets/tutor_showcase_card.dart` (212×208, parameter
  primitif): pil rating, nama, mapel + jenjang, "Mulai Rp… / 60 mnt", chip hari (maks 3 + "+n"),
  CTA "Lihat profil".
- Dua penyapu kecil: tautan "Kelas Grup" ganda di bagian Kekuatan & kelemahan dihapus (sudah ada
  di kartu promo), dan kartu "belum ada sesi terjadwal" kini bisa diketuk menuju Katalog.
- **Perbaikan lanjutan (permintaan pemilik):** bagian yang menggeser mendatar tidak boleh
  terpotong di batas margin; kontennya harus menyentuh tepi layar ("bleed").
  - Pola: ListView layar pakai `padding: EdgeInsets.only(bottom: 36)` (tanpa sisi), anak biasa
    dibungkus helper `sidePad(...)`; bagian mendatar dapat padding sisinya sendiri
    (`screenSide` / `EdgeInsets.symmetric(horizontal: 20)`).
  - Helper `screenSide` + `sidePad` ditaruh di `apps/mobile/lib/widgets/screen_head.dart`
    agar dipakai bersama; `screenPadding` lama tetap untuk layar tanpa bagian mendatar.
  - Karusel promo: `padEnds: false` + `viewportFraction: 0.94` di dalam `Padding(left: 20)`
    supaya kartu berikutnya hanya menyembul di tepi kanan, tetap ada snap + indikator.
  - Diterapkan di Beranda (promo + kartu tutor) dan Katalog (deretan chip mapel/mode).

## Alasan

- Kartu marketplace yang berhasil menaruh sinyal keputusan (harga, jadwal, rating) langsung di
  kartu; ini yang paling sering diminta siswa sebelum membuka profil.
- Menaruh ringkasan di view menjaga kartu tetap satu query dan konsisten antara Beranda/Katalog.
- Harga privat 60 menit adalah produk utama, jadi angka antar tutor apple-to-apple.

## Langkah berikutnya

- Pertimbangkan memakai `TutorShowcaseCard` di layar Katalog (kartu padanan, belum dipakai).
- Sisa polesan: sapaan Beranda menampilkan email saat profil belum termuat.

## Catatan operasional

- Build debug sempat gagal `No space left on device` (disk tersisa 1,8 GB; `build/` 8,5 GB).
  `flutter clean` di `apps/mobile` membebaskan ~11 GB. Pertimbangkan bersihkan `build/` bila
  build gagal dengan error disk.
