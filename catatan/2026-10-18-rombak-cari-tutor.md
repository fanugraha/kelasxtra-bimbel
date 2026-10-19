# Rombak halaman Cari Tutor (Katalog) siswa

## Konteks

Setelah Beranda dirapikan, pemilik meminta halaman **Cari Tutor** dirombak: daftar tutor
diminta berbentuk **kartu** (bukan baris), dan **filter diperbaiki** supaya siswa mudah
memfilter sesuai kebutuhannya. Pemilik meminta riset UX dulu, prioritas pengalaman
pengguna, tampilan cukup rapi, dan jarak antar elemen konsisten.

Masalah versi lama: semua pilihan ditumpuk dalam **satu deretan chip** yang mencampur mapel
dan mode; `KatalogFilter` sebenarnya sudah punya `jenjang` dan `minRating` tapi tidak pernah
ditampilkan; **tidak ada filter hari tersedia**, tidak ada filter harga, dan **tidak ada
urutan** (selalu rating tertinggi). Akibatnya kebutuhan nyata seperti "Matematika SMA hari
Rabu" tidak bisa dijawab layar ini.

## Keputusan atau temuan

- **Riset UX** (Baymard, panduan filtering Shopify, pola marketplace): filter punya tiga
  permukaan — pintu masuk, lembar pilihan, dan **penanda filter aktif di atas hasil**. Pola
  yang bertahan: chip cepat untuk beberapa filter tersering + tombol "Filter" yang membuka
  **lembar bawah** untuk sisanya; **urutan dipisah** dari filter; filter aktif harus terlihat
  dan bisa dilepas satu-satu; jangan pernah membiarkan 0 hasil tanpa jalan keluar.
- Keputusan pemilik: pola **chip cepat + lembar bawah**, dan **Hari tersedia** ikut jadi filter
  (boleh pilih beberapa hari).
- Yang diterapkan: `KatalogFilter` + `days`/`sort`; lembar bawah berisi Mapel, Jenjang, Mode,
  Hari tersedia, Rating minimum; tombol footer menyebut **jumlah hasil** ("Tampilkan 2 tutor")
  karena filter berlaku langsung — jadi siswa melihat dampaknya sebelum menutup lembar;
  chip filter aktif (badan chip atau ✕ sama-sama melepas) + "Hapus semua"; tombol `Filter (n)`;
  lembar "Urutkan" terpisah (Terbaik / Termurah / A–Z).
- Kartu tutor daftar memakai `TutorListCard` (kartu penuh) dengan bahasa visual Beranda:
  nama + pil rating, pendidikan, `Mapel · jenjang`, "Mulai Rp… / 60 mnt", chip hari, "Lihat profil".
  Komponen avatar/pil rating/harga/chip hari dipakai bersama `TutorShowcaseCard`.
- **Catatan teknis penting**: `Container(alignment: …)` akan **melebar penuh** di dalam `Wrap`
  (inilah sebab chip filter tampak jadi satu kolom). Solusinya: chip memakai padding vertikal,
  tanpa `alignment`, dan `Center` dipakai saat chip ada di ListView mendatar. Filter hari
  digabung dengan filter mode dalam satu query `tutor_availability`; urutan selalu diberi
  **urutan kedua** (pemutus seri) supaya posisi hasil tidak berubah-ubah.

## Alasan

- Filter yang selalu terlihat + lembar bawah menjaga layar hasil tetap bersih tanpa
  menyembunyikan kemampuan filter; jumlah hasil di tombol footer mencegah siswa menutup lembar
  tanpa sadar hasilnya kosong.
- Hari tersedia hanya terasa berguna kalau bisa dipilih beberapa hari sekaligus.
- Kartu penuh memberi sinyal keputusan (harga, jadwal) langsung di daftar, jadi siswa tidak
  perlu membuka profil satu per satu untuk menyaring.

## Langkah berikutnya

- Tambah data tutor (mis. satu harga lebih murah dengan rating lebih rendah, atau jadwal
  berbeda) supaya perbedaan "Termurah" vs "Terbaik" terlihat nyata di layar.
- Pertimbangkan jumlah hasil per pilihan filter (faceted count) bila katalog tutor sudah besar.
- Panelasan: badge jumlah filter di ikon (bukan hanya teks tombol) bila nanti filter bertambah.
