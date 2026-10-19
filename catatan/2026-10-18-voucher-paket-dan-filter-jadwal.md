# Voucher paket + penyaringan jadwal bentrok

## Konteks

Model paket-saja (4/8/12 pertemuan mingguan) belum mendukung voucher, dan wizard
beli paket menampilkan jam yang sudah terisi sehingga submit gagal dengan pesan
server "Jadwal … sudah terisi". Pemilik meminta: error tampil sebagai modal, dan
slot yang sudah terisi tidak muncul di pilihan jadwal.

## Keputusan atau temuan

- Voucher memakai ulang fungsi generik Fase 2 (`voucher_validate`,
  `check_voucher`, `reserve_voucher`) — tidak menulis validasi baru.
- `package_purchases` menyimpan snapshot `voucher_id` + `discount` (rupiah).
  Uang bayar = `price_total - discount`; tutor tetap 75% dari harga sesi normal.
- Redemption ditautkan ke paket (`voucher_redemptions.package_purchase_id`).
  Kuota dikunci saat Snap dibuat, ditandai `used` saat lunas, dilepas saat
  gagal/kedaluwarsa/refund (refund mengembalikan kuota).
- `refund_package` dihitung dari uang net (setelah diskon), bukan harga penuh.
- Penyaringan jadwal memakai RPC `tutor_busy_slots(tutor_id)` yang mengembalikan
  interval sibuk tutor (semua siswa) + milik pemanggil, tanpa identitas. Client
  menyaring tanggal/jam untuk SEMUA pertemuan mingguan sekaligus. Server tetap
  sumber kebenaran (`reserve_package_schedule`).
- Error submit ditampilkan lewat `AlertDialog`; slot sibuk di-invalidate agar
  pilihan ikut diperbarui.

## Alasan

- Reuse fungsi voucher menjaga perilaku booking dan paket sama.
- Snapshot diskon di paket membuat refund/payroll tidak perlu menghitung ulang.
- Filter di client mengurangi percobaan gagal; validasi server tetap menjaga
  balapan (dua siswa memilih slot sama).

## Langkah berikutnya

- Uji di HP: pilih Senin 17:00 (harus tidak muncul karena bentrok), voucher
  HEMAT10, lalu bayar.
- Belum ada penyapu otomatis paket `pending_payment` yang lock-nya kedaluwarsa.
- Dashboard belum menampilkan kolom voucher/diskon pada laporan paket.

## Alur setelah pembayaran (revisi)

Temuan: pembayaran sandbox sudah `settlement` dan paket aktif, tetapi layar hasil
tidak muncul karena Snap tidak menutup sendiri dan timer status di
`PaymentStatusScreen` berhenti saat data belum termuat (`_status() == null`).

Perbaikan:

- `SnapScreen` (kini `ConsumerStatefulWidget`) memantau `myPackagesProvider` tiap
  3 detik bila `packageId` diisi, lalu menutup sendiri saat paket `active`.
- `PaymentStatusScreen` polling 3 detik sampai status terminal (maks ~2 menit),
  tidak berhenti saat data belum termuat, dan menyegarkan saat app kembali aktif
  (`didChangeAppLifecycleState`).
- Layar sukses menampilkan total dibayar, ID pembayaran, ringkasan paket +
  jadwal + masa berlaku; CTA utama "Lihat jadwal", lalu "Kembali ke Beranda".
- Jika webhook lambat: fase "Menunggu pembayaran" dengan "Cek status"/"Bayar
  sekarang"; jika gagal: "Beli paket lagi".

Catatan: error "jam 9" sebelumnya berasal dari paket pending lama (Sabtu 09:00)
yang slotnya masih ditahan; setelah kedaluwarsa slot kembali tersedia. Pengguna
juga sempat mengubah/membatalkan satu pertemuan lewat menu Jadwal (tercatat di
`audit_logs`), sehingga urutan tanggal paket terlihat tidak mingguan.

