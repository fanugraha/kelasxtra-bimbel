# Progres Implementasi

Status per fase. Diperbarui setiap sesi. Acuan: [brief-implementasi-v2.0.md](brief-implementasi-v2.0.md).
Rencana lengkap: [RENCANA-DEV.md](RENCANA-DEV.md).

## Legenda
✅ selesai · 🟡 sebagian · ⬜ belum

## Ringkasan

| Fase | Nama | Status |
|---|---|---|
| 0 | Fondasi | ✅ |
| 1 | Akun & Profil | 🟡 |
| 2 | Katalog & Booking Privat + Pembayaran | 🟡 |
| 3 | Paket Sesi | 🟡 |
| 4 | Kelas Grup | 🟡 |
| 5 | Bank Soal + Analisis | 🟡 |
| 6 | Absensi, Reschedule, Komplain, Pesan | 🟡 |
| 7 | Payroll Bulanan | ⬜ |
| 8 | Dashboard Management & Operasional | ⬜ |
| 9 | Notifikasi & Hardening | ⬜ |

## Fase 0 — Fondasi (✅)

- [x] Monorepo: `apps/mobile`, `apps/dashboard`, `supabase/`, `docs/`, `catatan/`
- [x] Supabase migration: `profiles`, `students`, `tutors` (+ helper `is_admin`)
- [x] RLS deny-by-default untuk tabel Fase 0
- [x] Trigger `handle_new_user` (auto-buat profil saat signup)
- [x] Storage buckets: `avatars`, `question-assets`, `tutor-documents`
- [x] Master data: `levels`, `subjects`, `topics`, `price_matrix` + `seed.sql`
- [x] Flutter skeleton: 2 flavor (`main_siswa.dart` / `main_tutor.dart`), Riverpod, go_router, auth
- [x] Dashboard skeleton: React+TS+Vite, Supabase client, auth guard, registry modul
- [x] CI (lint + build) + `.gitignore` + README
- [x] MCP global dipasang: supabase, context7, playwright, github (butuh restart opencode)
- [x] Skill proyek `.opencode/skills/kelasxtra-bimbel/SKILL.md`
- [x] Library terpasang: mobile (`intl`, `geolocator`, `firebase_core`, `firebase_messaging`, `image_picker`), dashboard (`katex`, `react-katex`)
- [x] RLS diuji tolak akses silang user (cloud, 15 Okt 2026) — lihat catatan
- [x] Akun admin pertama dibuat (`admin@kelasxtra.id`, `role=admin`, `admin_role=null`; via MCP supabase 15 Okt 2026). Password awal harus diganti.
- [x] `flutter analyze` bersih setelah kredensial mobile (15 Okt 2026)
- [ ] **Utang keamanan**: rotate secret key lama (sempat salah taruh di `.env.example`) — manual di dashboard
- [ ] Validasi `supabase db reset` lokal (opsional; cloud sudah jadi acuan uji)

## Fase 1 — Akun & Profil (🟡)

- [x] Migrasi `audit_logs` (+ RLS: admin baca; insert hanya service role)
- [x] Edge Function `invite-tutor` (admin buat akun + token 7 hari; kirim email bila Resend aktif)
- [x] Edge Function `activate-tutor` (publik: validasi token → set password → isi profil/bank → aktif)
- [x] Edge Function `manage-tutor` (suspend/reactivate/resend undangan + audit log + ban akun saat suspend)
- [x] Dashboard modul **Tutor & Undangan** (buat, kirim ulang, suspend/reaktivasi)
- [x] Halaman aktivasi **web** `/activate?token=...` (dipilih dibanding deep link mobile — lihat catatan)
- [x] Registrasi siswa mandiri + checkbox izin + kontak darurat (dari Fase 0, tetap berlaku)
- [x] Uji end-to-end: invite → aktivasi web → `tutors.status='aktif'` (Playwright + SQL)
- [ ] **Email otomatis** undangan via Resend — **ditunda**. Keputusan: admin salin link & kirim manual (WhatsApp). Kode `invite-tutor` sudah siap kirim email; tinggal selesaikan DNS domain `kelasxtra.my.id` di Cloudflare lalu set `RESEND_API_KEY` (sudah diset, tapi domain belum Verified).
- [x] Katalog publik tutor: VIEW `public.tutor_catalog` (tanpa kolom bank/token) + cabut policy `tutors: baca tutor aktif` (migrasi `...00010_tutor_catalog_view`, 16 Okt 2026)
- [x] Mobile: layar **Profil** — data akun, jenjang/sekolah/kontak darurat (siswa), status langganan, keluar
      (menggantikan `PlaceholderScreen`, 17 Okt 2026)

## Fase 2 — Katalog & Booking Privat (🟡)

- [x] Migrasi `tutor_subjects`, `tutor_availability`, `vouchers`, `voucher_redemptions`, `bookings`, `payments` + RLS
  - `bookings`: `tutor_share`/`platform_share`/`amount_due` = **generated columns** (integer, `floor(price*75/100)`)
- [x] RPC `set_price` (ubah harga + versi lama jadi riwayat + tulis `audit_logs`)
- [x] Dashboard modul **Price Matrix** (edit harga inline + tampilkan riwayat)
- [x] Dashboard modul **Voucher** (CRUD, aktif/nonaktif, kuota)
- [x] VIEW `public.tutor_catalog` — katalog publik tutor tanpa kolom bank (bypass RLS disengaja; linter `security_definer_view` = known/intentional)
- [x] Edge Function `create-snap` (buat booking pending + Midtrans Snap)
- [x] Edge Function `midtrans-webhook` (idempoten by `order_id`; verifikasi signature SHA512)
- [x] Mobile siswa: katalog (daftar dari VIEW `tutor_catalog`, filter mapel+jenjang, urut rating) + profil tutor (mapel/jenjang + jadwal ketersediaan)
- [x] Mobile siswa: pilih slot → ringkasan harga → Snap (WebView) → status di tab **Jadwal** (voucher menyusul)
- [x] Slot lock 30 menit (`lock_expires_at`) + auto-expire via `pg_cron` (`expire_stale_bookings`, tiap 5 mnt)
- [x] Prasyarat Midtrans Sandbox: secret terpasang, webhook URL diset; **uji end-to-end di HP** (bayar → webhook settlement → booking `confirmed`)
- [x] Uji jalur webhook: gagal (deny/cancel→cancelled), expire, **duplikat → tidak dobel**, signature salah → 401
- [x] Alamat terbuka pasca-bayar + bagi hasil (`tutor_share`/`platform_share`) tak bocor ke client — VIEW `bookings_visible` (definer)
- [x] Voucher di checkout: validasi + kunci kuota race-safe (RPC), dilepas saat gagal (webhook)
- [x] Filter katalog: mapel, jenjang, mode, rating (filter *harga* ditunda — tutor tak punya satu harga; harga tergantung jenjang/durasi/mode)
- [ ] O7: harga final price matrix diisi pemilik lewat dashboard

## Fase 3 — Paket Sesi (🟡)

- [x] Migrasi `package_purchases` (+ `payments.package_purchase_id`, FK `bookings.package_purchase_id`)
- [x] Aturan: 4/8/12 sesi → diskon 0/5/10%; terikat 1 tutor + mapel/jenjang/durasi/mode; 90 hari; kuota hangus
- [x] RPC `consume_package_session` (atomik), `refund_package` (proporsional, admin), `expire_stale_packages` (+ cron)
- [x] Edge `create-package-snap` (beli) + `book-with-package` (pakai kuota); webhook cabang paket
- [x] Mobile: layar **Beli Paket** (dari profil tutor) + **Paket Saya** + opsi **pakai kuota** di booking
- [x] Dashboard: modul **Paket Sesi** — daftar pembelian + tombol refund proporsional (menghitung & mencatat; dana manual via Midtrans)
- [x] Uji backend: 8 sesi SMA 60 online → 646.000; aktif via webhook; pakai kuota → booking `confirmed` (bayar 0);
      kuota habis & slot bentrok ditolak; refund proporsional 484.500

## Fase 4 — Kelas Grup (🟡)

- [x] **O1 diputus**: min **3** siswa, tanpa subsidi, bayar sekali per kursi, tenggat H-1 20:00 WIB,
      <3 → program batal (pindah kelas/kredit dulu, refund penuh bila menolak). Cap 2 slot/minggu dibuang
- [x] Migrasi `rooms`, `group_classes`, `group_sessions`, `group_seats` (+ `payments.group_seat_id`, view publik)
- [x] RPC `admin_create_group_class` (buat program + susun pertemuan 2×/minggu), `reserve_group_seat` (atomik),
      `activate/release_group_seat`, `refund_group_seat` (admin), `settle_group_classes` + `expire_stale_group_seats` (cron)
- [x] Edge `create-group-seat-snap` + webhook cabang `group_seat`
- [x] Uji: 8 sesi (Sel & Kam 16:00) → 570.000, tenggat 19 Okt 20:00 WIB; ambil kursi → `pending`;
      settlement → `active`; deny → kursi dilepas; kuota <3 → program `cancelled`; kuota ≥3 → `confirmed`
- [x] Dashboard: modul **Kelas Grup** (buat program + pantau keterisian + refund kursi) & **Ruangan**
- [x] Mobile siswa: **Kelas Grup** (daftar program, lihat 8 pertemuan, ambil kursi → Snap)

## Fase 5 — Bank Soal + Analisis (🟡)

- [x] **Keputusan bayar langganan**: **C** — bulanan manual (Snap, semua metode) + tenggang 3 hari;
      auto-potong (kartu) menyusul. Harga di tabel `subscription_plans` (Rp29.000/30 hari, tenggang 3)
- [x] Skema: `subscription_plans`, `subscriptions`, `questions`, `question_versions`, `attempts`,
      `attempt_answers`, `student_topic_stats` + RLS
- [x] RPC `start_attempt` (soal **tanpa** kunci jawaban; gerbang langganan) & `submit_attempt`
      (penilaian di server + update `student_topic_stats`: akurasi, 20-terakhir, tren)
- [x] Cron `refresh_subscription_statuses` (active → grace → expired)
- [x] Uji: soal terkunci tidak bocor; 2/3 benar → akurasi 66.67%, 20-terakhir 2/3, tren null (<5);
      langganan nonaktif → `start_attempt` ditolak
- [x] CMS soal (dashboard): KaTeX + gambar, tag topik/jenjang, draf→review→tayang, versioning
- [x] RPC `admin_save_question` (edit = versi baru), `admin_set_question_status`; view `questions_admin`
      (security_invoker → siswa 0 baris, kunci jawaban tetap aman)
- [x] Langganan backend: Edge `create-subscription-snap`, RPC `activate_subscription`, webhook cabang
      `subscription` (bulan manual via Snap + tenggang 3 hari; auto-potong kartu menyusul)
- [x] Teruji: beli 29.000 → settlement → langganan +30 hari (tenggang +3)
- [x] **Mobile bank soal: teruji di HP (17 Okt)** — analyze bersih, test 12/12, APK rilis terpasang;
      latihan Trigonometri 4/4 → skor 100 + pembahasan, tryout 20 soal timer jalan
      (lihat catatan `2026-10-17-fase-5-bank-soal.md`)
- [x] Tryout: 20 soal acak, timer 20 menit, auto-submit saat waktu habis (17 Okt 2026)
- [x] Soal dummy: 5 soal/topik untuk 10 topik (`supabase/seed_questions.sql`, idempoten)
- [ ] Auto-potong kartu (Midtrans recurring)

## Fase 6 — Absensi, Reschedule, Komplain, Pesan (🟡)

- [x] Skema: `booking_reschedules`, `session_notes`, `reviews`, `complaints`, `tutor_earnings`,
      `booking_threads`, `thread_messages`, `group_attendance` + kolom absensi/refund/reschedule
      di `bookings`, koordinat di `rooms`
- [x] RPC absensi: `tutor_checkin` (jendela ±15 menit, geofence 200 m bila titik acuan ada),
      `student_attend`, `mark_no_show`, `save_session_note`, `complete_booking`
- [x] Cron `auto_complete_bookings` (tiap 15 menit): tutor tanpa check-in → `no_show_tutor`;
      sesi berjalan tanpa komplain s/d H+1 → `completed`
- [x] RPC `reschedule_booking` (atomik, maks 14 hari, maks 2x, tanpa ganti mode, cek bentrok + expiry paket)
- [x] RPC `cancel_booking` (>24 jam refund penuh/kuota kembali; <24 jam 50%/kuota hangus; dana manual)
- [x] RPC komplain `open_complaint` (H+3) & `resolve_complaint` (admin; refund dicatat, earnings ditahan/dilepas)
- [x] RPC `submit_review` (1 per booking, H+3, update `tutors.rating_avg`)
- [x] Thread pesan otomatis saat `confirmed`; RPC `send_booking_message` (nomor telepon disamarkan + flag)
- [x] RPC kehadiran grup `mark_group_attendance`
- [x] Uji SQL (transaksi rollback): check-in → hadir → catatan → selesai → earnings 75.000/25.000;
      ulasan 5 → rating tutor 5.00; komplain → `disputed` + earnings `ditahan`; resolve refund 30.000;
      reschedule +1 hari (counter 1); batal >24 jam refund 100.000; auto-complete H+1 + earnings
- [x] Mobile: layar **Detail Sesi** (`/sesi/:id`) — aksi absensi/reschedule/batal/ulasan/komplain + chat
- [x] Dashboard: modul **Komplain** (filter status, selesaikan/tolak + refund)
- [x] Perbaikan RLS pasca-uji: policy Fase 6 tak boleh subquery `bookings` (pakai helper definer)
- [ ] Kehadiran grup di UI tutor (RPC & tabel sudah ada)
- [ ] Titik lokasi untuk geofence privat (kolom `bookings.location_lat/lng` belum diisi dari UI)
- [x] Uji flavor tutor di HP: login tutor → tab **Jadwal** → Mulai sesi → catatan → selesai
      (status `completed`, earnings 56.250/18.750 `belum_dibayar`); chat terkirim
- [x] Tab **Jadwal** ditambahkan ke navigasi tutor + guard "Akun ini bukan tutor" di Beranda

## Langkah berikutnya

1. Uji flavor tutor di HP (check-in → catatan → selesai) + uji komplain dashboard.
2. Lengkapi UI kehadiran grup & isi titik lokasi (rooms/booking) untuk geofence.
3. Fase 7 — payroll bulanan dari `tutor_earnings`.
4. Set secret email: `supabase secrets set RESEND_API_KEY=... EMAIL_FROM="Kelasxtra <noreply@domainmu>" ACTIVATION_BASE_URL="https://<domain-dashboard>/activate"`.
5. Konfigurasi Supabase SMTP (Resend) untuk email auth siswa.
