# Slicing UI Dashboard Admin

## Konteks
Desain HTML statis `kelasxtra-admin-dashboard.html` (13 layar + shell) dan `kelasxtra-mobile-tutor.html`
sudah dibuat pemilik. Dashboard React yang ada sudah punya query/mutasi Supabase, tetapi tampilannya
masih CSS lama. Pekerjaan dimulai dari dashboard, mobile menyusul.

## Keputusan atau temuan
- Token desain (warna, font, radius, shadow, dark mode, responsive drawer) dipindahkan ke
  `apps/dashboard/src/index.css`; font Plus Jakarta Sans + Nunito Sans via Google Fonts.
- Shell ditulis ulang: sidebar 3 grup (Operasional, Bisnis, Layanan & konten), breadcrumb, tanggal WIB,
  toggle tema (`kx-admin-theme`), kartu admin + logout, drawer mobile.
- Label navigasi mengikuti desain (mis. Price Matrix → Daftar Harga, Payroll → Gaji Tutor), path route tetap.
- Semua 13 layar di-slice ulang. Logika Supabase lama dipertahankan; angka demo desain tidak dipakai.
  Data kosong tampil sebagai empty state asli, bukan angka palsu.
- Overview memakai `admin_metrics` + `payments` 7 hari + `bookings_visible` hari ini.
- Dua bug query diperbaiki: laporan voucher memakai `bookings_visible` (bukan `bookings` yang 403);
  komplain mengambil `complaints` lalu `bookings_visible` terpisah (embed `bookings` kena RLS).
- Ruangan sekarang memilih `lat`/`lng` saat load agar tombol atur lokasi berfungsi.

## Alasan
Desain adalah sumber tampilan; Supabase tetap sumber data. Memisahkan query dari RLS yang tidak
mengizinkan tabel dasar menghindari halaman kosong/403 tanpa melonggarkan policy.

## Langkah berikutnya
- Verifikasi visual detail (spacing/typography) dengan pemilik, lalu rapikan warning lint `Date` di render.
- Lanjut slicing `kelasxtra-mobile-tutor.html` ke `apps/mobile` (entry point tutor).
