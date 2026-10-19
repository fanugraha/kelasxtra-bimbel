# Model paket: pertemuan mingguan, harga admin, paket-saja

## Konteks
Pemilik ingin menyederhanakan penjualan: siswa tidak lagi membeli per sesi, hanya
paket 4/8/12 pertemuan. Redesain alur bayar (detail tutor → Snap → status) selesai
lebih dulu; sesi ini fokus mengubah model paketnya.

## Keputusan atau temuan
Enam keputusan pemilik (final):
1. Tombol "Pesan Sesi" dihapus dari aplikasi siswa; hanya beli paket. Mesin "sesi"
   tetap dipakai di balik layar (1 pertemuan = 1 sesi/booking).
2. Jadwal dipilih saat membeli: hari + jam + tanggal mulai; sistem membuat 4/8/12
   pertemuan mingguan ke menu Jadwal. Reschedule per pertemuan tetap ada.
3. Masa berlaku mengikuti jumlah pertemuan: 4 = 1 bulan, 8 = 2 bulan, 12 = 3 bulan.
4. Harga paket ditetapkan admin di tabel harga paket (bukan hitung sesi × jumlah
   dengan diskon 0/5/10%).
5. Bagian tutor tetap 75% harga sesi normal; diskon paket ditanggung platform.
   Admin diberi peringatan bila harga paket di bawah total bagian tutor.
6. Kerjakan semuanya sekaligus (DB, alur siswa, layar admin, dokumentasi).

Temuan mesin lama: `bookings.tutor_share` adalah kolom generated `(price * 75) / 100`,
jadi bagian tutor otomatis dari harga booking. Edge Function `book-with-package`
dibiarkan sebagai legacy (tidak dipakai aplikasi lagi). Tidak ada penyapu untuk paket
`pending_payment` yang kadaluarsa (sengaja diterima untuk sekarang).

## Alasan
Jadwal dibuat saat Snap (bukan saat webhook) supaya pertemuan tampil di Jadwal sejak
pembayaran dimulai; webhook hanya mengubah status (`activate_package` /
`cancel_package_reservation`), sehingga idempoten dan tidak menggandakan pertemuan.
Harga paket disimpan eksplisit karena pemilik ingin menetapkan harga jual sendiri,
bukan hasil perhitungan diskon.

## Langkah berikutnya
1. Uji di HP: beli paket → 4/8/12 pertemuan mingguan muncul di Jadwal, kuota &
   masa berlaku benar, tombol "Lanjutkan bayar"/"Ubah jadwal" jalan.
2. Uji halaman admin "Harga Paket" (peringatan harga di bawah bagian tutor).
3. Bersihkan booking uji yang menggantung, lalu perbarui `docs/PROGRES.md`.

## Sudah dikerjakan (18 Okt, lanjutan)
`docs/brief-implementasi-v2.0.md` direvisi agar cocok dengan model baru: paket 4/8/12
pertemuan berjadwal mingguan dengan harga ditetapkan admin (siswa hanya beli paket,
tanpa penjualan per sesi), bagi hasil tutor 75% harga sesi normal + platform menanggung
diskon paket, masa berlaku 1/2/3 bulan, refund dari pertemuan yang belum berjalan.
Sekaligus disesuaikan: penjaga teks + chat/moderasi (Fase 10 baru), kelas grup min 3
siswa tanpa subsidi (cap 2 slot/minggu dibuang), langganan bulanan manual + tenggang 3
hari, out-of-scope "penjualan per sesi" & "FCM ditunda". Item PROGRES untuk revisi brief
ditandai selesai. Catatan: `docs/arsitektur.md`, `docs/erd.md`, `docs/PRD-UI.md`,
`docs/RENCANA-DEV.md`, `docs/prd-v1.0.md` masih memakai model lama (belum direvisi).
