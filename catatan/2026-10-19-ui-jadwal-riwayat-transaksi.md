# UI Jadwal & halaman Riwayat transaksi (19 Okt 2026)

## Konteks

Halaman Jadwal memuat dua hal sekaligus: agenda sesi dan jejak uang, sehingga sulit
dibaca. Pemilik meminta Jadwal berisi agenda sesi saja, riwayat transaksi dipindah ke
halaman sendiri, dan semua halaman diberi margin atas 20 px.

## Keputusan atau temuan

- **Jadwal = agenda sesi saja.** Dua tab (`Akan datang`, `Selesai`), dikelompokkan per
  tanggal dengan label `Hari ini`/`Besok`/`Sen, 20 Okt` + jumlah sesi.
- Kartu sesi baru (`features/jadwal/widgets/session_card.dart`, dipisah dari layar sesuai
  aturan struktur): blok jam di kiri, mapel sebagai judul, badge status, baris
  `Tutor`/`Siswa`, mode + rentang jam WIB, lalu aksi utama
  (`Bayar sekarang` untuk `pending_payment` → membuka Paket Saya, `Detail sesi`,
  `Beri ulasan`) + `Chat`.
- Booking `pending_payment` tetap muncul di Jadwal sebagai pengingat; pembayarannya
  dilakukan dari kartu paket (halaman Paket Saya) karena tagihan yang belum lunas adalah
  paket, bukan sesi tunggal.
- **Halaman baru "Riwayat transaksi"** (`/riwayat-transaksi`, dibuka dari baris di Profil
  siswa) menggabungkan empat sumber: paket (`package_purchases`), sesi satuan (payment
  booking), langganan bank soal (`subscriptions` + `subscription_plans`), kursi kelas grup
  (`group_seats`); dikelompokkan per bulan.
- **Batas RLS**: siswa hanya bisa membaca `payments` yang terhubung ke booking-nya
  (`booking_has_student`), jadi pembelian paket dibaca dari `package_purchases`, bukan dari
  `payments`.
- Margin atas diseragamkan 20 px lewat `ScreenHead` (18→20) dan `HomeHead` (8→20); layar
  yang memakai `AppBar` dibiarkan.

## Alasan

Agenda dan uang punya kebutuhan berbeda: agenda fokus "apa berikutnya" (per hari, aksi
cepat), riwayat fokus "apa yang sudah dibayar" (per bulan, nominal + status). Memisahkannya
membuat keduanya lebih ringkas, dan siswa tetap bisa mengingat tagihan yang belum lunas
lewat kartu di Jadwal.

## Langkah berikutnya

- Uji di HP: kartu sesi baru, tombol "Bayar sekarang" dari Jadwal, dan halaman riwayat
  (termasuk saat ada paket pending + kursi kelas grup + langganan sekaligus).
- Bila perlu, tambahkan ringkasan total per bulan di halaman riwayat.
