# Model Data (ERD)

Daftar tabel inti. Kolom **Fase** menandai kapan tabel dibuat.
Tabel bertanda ✔ sudah ada di migrasi Fase 0.

| # | Tabel | Fungsi | Fase |
|---|---|---|---|
| 1 | `profiles` ✔ | Akun: role student/tutor/admin + admin_role | 0 |
| 2 | `students` ✔ | Profil siswa (1:1 profiles) + kontak darurat | 0 |
| 3 | `tutors` ✔ | Profil tutor (diundang/aktif/suspend), data bank | 0 |
| 4 | `levels` ✔ | Jenjang SD/SMP/SMA | 0 |
| 5 | `subjects` ✔ | Master mapel | 0 |
| 6 | `topics` ✔ | Topik per mapel × jenjang | 0 |
| 7 | `price_matrix` ✔ | Harga per jenjang × durasi × mode × tipe | 0 |
| 8 | `tutor_availability` | Slot ketersediaan mingguan tutor | 2 |
| 9 | `package_purchases` | Paket dibeli: student, tutor, total/sesi_terpakai, expires_at | 3 |
| 10 | `bookings` | Satu sesi: jadwal UTC, durasi, mode, harga_snapshot, status, lock_expires_at | 2 |
| 11 | `booking_reschedules` | Riwayat pindah jadwal | 6 |
| 12 | `group_classes` | Slot kelas grup (tutor, kapasitas 5, ruangan) | 4 |
| 13 | `group_seats` | Kursi terbooking per siswa per kelas | 4 |
| 14 | `payments` | Transaksi Midtrans (order_id unik, tipe, amount, status) | 2 |
| 15 | `subscriptions` | Langganan bank soal (Midtrans recurring id) | 5 |
| 16 | `questions` | Soal + tag topik/level | 5 |
| 17 | `question_versions` | Versioning soal (edit tak merusak riwayat) | 5 |
| 18 | `attempts` | Percobaan latihan/tryout per siswa | 5 |
| 19 | `attempt_answers` | Jawaban per siswa per versi soal | 5 |
| 20 | `student_topic_stats` | Agregat akurasi per siswa per topik | 5 |
| 21 | `tutor_earnings` | Ledger penghasilan per sesi (append-only) | 6–7 |
| 22 | `payouts` | Rekap payroll bulanan per tutor | 7 |
| 23 | `session_notes` | Materi + progres siswa per sesi (wajib) | 6 |
| 24 | `reviews` | Rating & ulasan (1 per booking, maks H+3) | 6 |
| 25 | `complaints` | Tiket komplain + keputusan + refund_nominal | 6 |
| 26 | `booking_threads` | Thread pesan per booking | 6 |
| 27 | `thread_messages` | Pesan dalam thread | 6 |
| 28 | `rooms` | Master ruangan offline (anti double-booking) | 4 |
| 29 | `notifications` | Antrean notifikasi push | 9 |
| 30 | `audit_logs` | Jejak aksi sensitif (sebelum/sesudah) | 1 |

> Brief menyebut "ERD 29 tabel"; daftar di atas 30 baris (subjects & topics terpisah).
> Jumlah pasti akan dikonfirmasi bila `bimbel-rancangan-produk.md` ditemukan.

## Relasi kunci

- `profiles 1—1 students`, `profiles 1—1 tutors`
- `tutors 1—N tutor_availability`, `bookings`, `group_classes`
- `students 1—N bookings`, `package_purchases`
- `package_purchases 1—N bookings` (booking pakai kuota)
- `bookings 1—1 payments` (order per booking), `1—N complaints`, `1—1 session_notes`, `1—N reviews`
- `bookings 1—N tutor_earnings` (ledger per sesi)
- `tutors 1—N payouts`, `payouts N—1 tutor_earnings` (rekap periode)
- `subjects 1—N topics`, `topics 1—N questions`

## Storage buckets

| Bucket | Akses | Pakai |
|---|---|---|
| `avatars` | publik | foto profil |
| `question-assets` | privat | soal bergambar |
| `tutor-documents` | privat | **tidak dipakai di MVP** (rekrutmen offline) |
