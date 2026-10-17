# Slicing UI Mobile Siswa & Tutor

## Konteks
Dua desain HTML (`kelasxtra-mobile-android.html`, `kelasxtra-mobile-tutor.html`) diimplementasikan ke
Flutter `apps/mobile`. Satu codebase, dua entry point (`main_siswa.dart` / `main_tutor.dart`).
Backend dan provider lama dipertahankan; pekerjaan fokus pada tampilan dan navigasi.

## Keputusan atau temuan
- Token desain mobile dipakai ulang: warna indigo/ungu, Nunito, kartu radius 18, padding layar 20,
  badge status, dan bayangan kartu halus.
- Shell diganti dari `NavigationBar` Material ke tab bar kustom. Tutor sekarang punya 5 tab:
  Beranda, Jadwal, Absensi, Gaji, Profil. Siswa tetap 4 tab.
- Beranda dipisah per flavor: siswa melihat promo, kekuatan/kelemahan dari `myStatsProvider`,
  jadwal berikutnya, tutor pilihan; tutor melihat sesi berikutnya, statistik, jadwal terdekat,
  dan kartu absensi kelas grup.
- `BookingItem` ditambah `studentName` (diambil dari tabel `students`) agar jadwal tutor tidak
  menampilkan nama tutor sendiri.
- Halaman yang di-slice: Jadwal (segmented), Absensi (tandai hadir/alpa), Gaji (estimasi + slip),
  Profil (data + tema), Katalog (search + chip filter), Paket, Kelas Grup, Bank Soal, Tutor Detail,
  Booking, Detail Sesi, Notifikasi, Login, Daftar.
- Tema gelap bisa di-toggle dari header/profil lewat `themeModeProvider` (belum persisten antar restart).

## Alasan
Desain mobile menekankan navigasi jempol dan kartu ringkas. Tab bar kustom + header tanpa AppBar
memberi ruang lebih besar dan terasa sama dengan prototipe, tanpa mengubah alur data.

## Langkah berikutnya
- Uji di HP untuk kedua flavor (login tutor/siswa, jadwal, absensi, bayar).
- Pertimbangkan penyimpanan preferensi tema (mis. `shared_preferences`) bila toggle perlu persisten.
- Rapikan sisa layar kuis/hasil agar identik dengan prototipe bila dibutuhkan.
