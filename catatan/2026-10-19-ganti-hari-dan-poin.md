# Kebijakan uang: ganti hari berpasangan & poin siswa

## Konteks

Kebijakan lama mengembalikan uang (refund) untuk pembatalan dan komplain. Pemilik
mengubah arah: **tidak ada pengembalian uang dalam bentuk apa pun**. Nilai yang
dikembalikan ke siswa berbentuk **poin** (1 poin = Rp1) yang memotong pembayaran
berikutnya. Siswa juga tidak boleh lagi membatalkan sesi sendiri — ganti hari harus
disetujui pihak lain supaya tidak ada jadwal yang hilang.

## Keputusan atau temuan

- Poin disimpan sebagai ledger `student_credits` (bukan kolom saldo), saldo dihitung
  dari jumlah baris. Alasan yang boleh menambah poin: `tutor_no_show`, `complaint`,
  `manual`, `package_cancel`, `group_cancel`; pemakaian hanya `checkout` (amount < 0).
- Poin **otomatis hanya** saat tutor tidak hadir:
  - sesi **satuan** → poin sebesar `amount_due` (dipicu trigger saat status berubah
    ke `no_show_tutor`, idempoten lewat index unik pada `booking_id`);
  - sesi **paket** → bukan poin, melainkan pertemuan **wajib dijadwalkan ulang** oleh
    tutor (`reschedule_no_show`, batas 7 hari, kuota tetap terpakai).
- Admin boleh memberi poin manual (jalur komplain, `grant_student_credit`), nominal
  diputuskan admin dan dibatasi `≤ amount_due`.
- Siswa **memilih** memakai poin saat membeli paket (bukan otomatis) — bagian Edge
  Function belum dikerjakan.
- Pembatalan oleh admin: `cancel_booking` mengembalikan `refund_amount = 0` tetapi
  **kuota paket dikembalikan** (kuota bukan uang). Paket/kursi dibatalkan lewat
  `cancel_package_with_credit` / `cancel_group_seat_with_credit` yang mengubah sisa
  nilai menjadi poin.
- Ganti hari: tabel `reschedule_requests` dengan **satu pengajuan pending per booking**;
  pengajuan wajib ≥24 jam sebelum sesi, alasan ≥5 huruf, tujuan ≤14 hari, dan slot tujuan
  harus benar-benar kosong (`tutor_free_at` + `slot_is_free`). Batas jawaban
  `min(now()+12 jam, jadwal − 2 jam)`; cron menandai `expired` bila lewat.
- `reschedule_booking` dan `cancel_booking` sekarang **admin-only** (siswa/tutor dapat
  galat `42501`).
- Jebakan: `create or replace function` tidak bisa mengubah **nama parameter** — fungsi
  `resolve_complaint` lama harus di-`drop` dulu (galat `42P13`). `apply_migration` MCP
  bersifat atomik, jadi percobaan yang gagal tidak meninggalkan perubahan.
- `spend_credits` hanya untuk `service_role` (Edge Function), bukan klien; memakai
  `pg_advisory_xact_lock` per siswa agar tidak ada pemakaian ganda.

## Alasan

- Poin (bukan uang) menutup celah biaya admin & risiko penyalahgunaan Midtrans, sekaligus
  tetap memberi kompensasi yang adil kepada siswa.
- Kebijakan "tidak bisa batal, ganti hari harus disetujui" menjaga jadwal tutor tidak
  bolong sepihak dan menghindari sengketa refund.
- Ledger + saldo terhitung memudahkan audit dan menghindari salah hitung saldo.

## Langkah berikutnya

1. Deploy Edge Function yang diubah — **sudah dilakukan** (6 fungsi, `supabase
   functions deploy`, memakai CLI karena sudah ter-link; typecheck sebelumnya lewat
   harness tsc). Langkah lanjut: uji pemakaian poin end-to-end (potong sebagian dan
   potong penuh) dengan akun siswa berpoin.
2. Uji klik dashboard (Paket/Komplain/Kelas Grup) dan uji ganti hari end-to-end di HP
   (siswa mengajukan → tutor menerima → jadwal berpindah).
3. Siswa pada status `no_show_tutor` (paket) belum punya teks penjelasan di Detail Sesi —
   pertimbangkan menambah keterangan bahwa tutor yang menjadwalkan ulang.

## Catatan tambahan: pemakaian poin saat bayar (19 Okt 2026)

- Poin **tidak** dipotong saat Snap dibuat, melainkan **saat pembayaran lunas**, supaya
  poin tidak hilang bila pembayaran kedaluwarsa. Caranya: Edge Function menyimpan
  rencana potongan di `payments.credit_amount`, lalu `applyPaymentOutcome`
  (`_shared/paymentApply.ts`) memanggil `spend_credits` ketika hasil Midtrans = lunas.
  Jalur webhook/reconcile/resolve-payment-review otomatis ikut karena memakai fungsi
  yang sama.
- Bila poin menutup seluruh harga, pesanan langsung lunas **tanpa Midtrans**: Edge
  menulis payment `amount = 0` lalu memakai jalur `applyPaymentOutcome` yang sama
  (paket/kursi/booking jadi aktif). Respons memuat `paid: true`.
- Voucher tetap dihitung lebih dulu (diskon), baru poin memotong sisanya; poin dipakai
  maksimal sebesar tagihan (`min(saldo, tagihan)`).
- Kalau saldo berubah di antara Snap dibuat dan pembayaran lunas, `spend_credits`
  menolak → pembayaran ditandai `review_required` untuk ditindaklanjuti admin
  (tidak ditelan diam-diam).
