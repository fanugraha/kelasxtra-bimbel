# Penyempurnaan UI mobile, profil, notifikasi, dan kelas grup

## Konteks
Melanjutkan sesi Claude Code pada 20 Oktober 2026. Fokus: merapikan pengalaman siswa/tutor di mobile, menyelesaikan alur kelas grup, dan menyiapkan APK release dengan kredensial Supabase baru. Pekerjaan keamanan/rotasi kredensial dicatat di `2026-10-20-perbaikan-temuan-strix.md`.

## Keputusan atau temuan
- **Login** dibuat bergaya aplikasi super: hero brand + karusel manfaat otomatis, lalu lembar formulir putih. Karusel diringkas saat keyboard muncul agar kolom isian tetap terlihat.
- **Profil** dirombak menjadi kartu identitas (foto bisa diganti), dompet & aktivitas (poin, riwayat transaksi, langganan), biodata, keamanan akun, pengaturan, dan keluar. Tutor memakai layar yang sama tanpa bagian khusus siswa.
- Halaman baru: **Edit biodata** (nama, HP, jenjang, sekolah, tanggal lahir, kontak darurat, unggah avatar), **Ubah password** (verifikasi password lama + indikator kekuatan), dan **Riwayat poin** (saldo, penjelasan 1 poin = Rp1, riwayat masuk/terpakai).
- **Notifikasi** dikelompokkan per jenis (pesan, jadwal, keuangan, ulasan, peringatan), ada ringkasan belum dibaca dan aksi “Tandai semua”. Notifikasi baru bisa membawa `booking_id`.
- **Katalog** punya mode Privat/Grup, tombol filter yang menyebut jumlah filter aktif, dan kartu kelas grup yang konsisten dengan tab Bimbel.
- **Kelas grup**: kursi ditahan 5 menit saat bayar, `seats_taken` menghitung kursi lunas + tahanan, tampilan “terisi” hanya kursi lunas, dan kursi tahanan punya penanda jam. Detail kelas satu halaman: ambil kursi → konfirmasi + poin → QRIS. Pembayaran terlambat setelah tahanan dilepas akan mencoba mengambil kursi lagi; bila gagal, payment ditandai untuk refund.
- **Dashboard**: halaman aktivasi tutor menambahkan permintaan dan verifikasi OTP 6 digit; teks undangan diperbarui.
- **iOS**: menambahkan izin akses galeri foto untuk avatar.
- Label navigasi “Cari” diganti “Bimbel”; beranda siswa mendapat pintu tetap ke kelas grup.

## Verifikasi
- `flutter analyze` bersih.
- `flutter test` 64 tes lulus. Beberapa preview test mencatat peringatan `google_fonts` gagal mengambil font saat offline, tetapi tes tetap lulus.
- Dashboard `npm run lint` hanya memunculkan 6 peringatan lama (purity/set-state); `npm run build` sukses.
- APK release siswa dan tutor dibangun ulang dengan publishable key baru, masing-masing 63 MB, dipindai (publishable ada, legacy anon tidak ada), lalu dipasang di HP `e68890180406`.

## Langkah berikutnya
- Uji manual alur login, edit biodata/avatar, ubah password, riwayat poin, notifikasi, dan pembelian kelas grup di HP.
- APK release masih memakai debug signing key (TODO lama di `android/app/build.gradle.kts`); siapkan keystore sebelum distribusi/Play Store.
- Sisa risiko keamanan: `submit_attempt` masih bisa membocorkan kunci jawaban, leaked-password protection Supabase belum aktif, dan 6 view `SECURITY DEFINER` masih dilaporkan advisor.
