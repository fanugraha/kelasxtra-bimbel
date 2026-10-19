# Redesign UI mobile dengan acuan Best-Flutter-UI-Templates

## Konteks

Pemilik ingin tampilan mobile mengikuti repo
`mitesh77/Best-Flutter-UI-Templates`. Dipilih gaya **Design Course + Hotel
Booking** (kartu putih, aksen cyan/teal, sudut membulat, label kategori pil)
untuk **semua layar siswa dan tutor**.

## Keputusan atau temuan

- Repo acuan adalah kumpulan aplikasi demo, bukan design system. Yang diambil
  hanya bahasa visualnya; kode dan aset demo tidak disalin. Lisensi repo MIT,
  tetapi README meminta tidak dijual — tetap cantumkan atribusi bila aset dipakai.
- Palet baru: primary `#007FA3` (kontras teks putih aman), aksen cyan
  `#00B6F0`, teal `#54D3C2`, coral `#FF7A59`, latar `#F3F7F9`, teks navy
  `#17262A`. Mode gelap ikut disesuaikan.
- Tipografi pindah dari Nunito ke **WorkSans** (ukuran body tetap >=15sp).
- Radius: kartu 20, tombol 16, sheet 28. Kartu memakai border halus + bayangan
  lembut; tombol utama lebih tinggi (50).
- Perubahan terpusat di `core/theme/` dan `core/widgets/` supaya seluruh layar
  ikut berubah tanpa menulis ulang tiap halaman.
- Sentuhan layar utama: kartu promo Beranda, kartu tutor, hero tutor, statistik
  tutor, chip filter terpilih (isi penuh), segmented Jadwal, kartu profil
  bergradien, header login, empty state, dan status badge.
- Bottom nav memakai pola **My Diary**: bilah putih/mode-gelap melengkung dengan
  notch di tengah + tombol lingkaran gradien menonjol. Tab tengah adalah tab
  ke-3 (Jadwal untuk siswa, Absensi untuk tutor); label tetap ditampilkan di
  bawah tombol agar tidak ambigu. Lima tab tetap utuh.
- Kartu tutor kini bergaya marketplace (Shopee/Halodoc): area foto di atas,
  badge terverifikasi + rating menimpa foto, informasi di bawah. Beranda memakai
  kartu horizontal; Katalog memakai grid 2 kolom (3 kolom di layar lebar).
  Bila tutor belum punya foto, tampil ilustrasi gradien + inisial + ikon mapel,
  bukan area kosong.
- Jadwal memakai foto tentor berukuran sedang (rounded square + badge centang)
  di kartu sesi dan header grup tentor, meniru kartu profil dokter Halodoc.
- Tidak menambah dependency baru; font tetap lewat `google_fonts`.

## Alasan

- Mengubah token + widget bersama memberi hasil menyeluruh dengan risiko dan
  diff lebih kecil daripada menyalin layar demo.
- Warna utama dibuat lebih gelap dari cyan template agar teks putih pada tombol
  tetap terbaca (WCAG AA), sementara cyan terang tetap dipakai sebagai aksen.

## Langkah berikutnya

- Pratinjau di HP siswa & tutor, terutama Beranda, Katalog, detail tutor, dan
  Jadwal; cek overflow di layar 360dp.
- Bila ingin lebih dekat lagi dengan template, pertimbangkan gambar hero/ilustrasi
  katalog (butuh aset baru + atribusi).
- Hasil verifikasi: `flutter analyze` bersih, `flutter test` 35 tes lolos.
- Diuji di HP Android 12: Beranda, Katalog grid, tombol tengah Jadwal, dan
  bottom nav; tidak ada overflow/exception.
