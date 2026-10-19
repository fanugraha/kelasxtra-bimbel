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
| 7 | Payroll Bulanan | 🟡 |
| 8 | Dashboard Management & Operasional | 🟡 |
| 9 | Notifikasi & Hardening | 🟡 |

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
- [x] Kehadiran grup di UI tutor: tab **Absensi Grup** (view `group_attendance_visible`) — 3 status per siswa
- [x] Titik lokasi ruangan di dashboard (lat/lng) untuk acuan geofence
- [ ] Titik lokasi booking privat (kolom `bookings.location_lat/lng` belum diisi dari UI)
- [ ] Uji UI absensi grup di HP (perlu login tutor pemilik kelas grup)
- [x] Uji flavor tutor di HP: login tutor → tab **Jadwal** → Mulai sesi → catatan → selesai
      (status `completed`, earnings 56.250/18.750 `belum_dibayar`); chat terkirim
- [x] Tab **Jadwal** ditambahkan ke navigasi tutor + guard "Akun ini bukan tutor" di Beranda

## Fase 7 — Payroll Bulanan (🟡)

- [x] Skema: `payroll_periods`, `payouts`; `tutor_earnings.payout_id`, `session_at`, `source`
      (booking/group), `group_session_id`, `paid_at`; snapshot rekening + `transfer_ref`
- [x] RPC `admin_generate_payroll` (kunci periode, cut-off WIB, hanya earning `belum_dibayar`
      yang belum punya payout), `admin_approve_payroll` (four-eyes), `admin_cancel_payroll`,
      `admin_mark_payroll_paid` (+ audit log)
- [x] Honor kelas grup: `ensure_group_earnings` + cron 15 mnt (75% × harga kursi × kursi aktif)
- [x] Uji SQL: earning ditahan komplain tidak ikut rekap; honor grup 56.250 masuk payout;
      approval admin lain + `TRF-TEST-001` → `sudah_dibayar`; approve pembuat sendiri ditolak
- [x] Dashboard modul **Payroll** (rekap, approve, batal draft, tandai transfer, CSV)
- [x] Mobile tutor: layar **Penghasilan** (slip baca-saja)
- [x] Admin kedua: `finance@kelasxtra.id` (admin_role finance) untuk four-eyes
- [x] Uji UI payroll di browser (rekap + batal draft)
- [ ] Uji slip Penghasilan di HP

## Fase 8 — Dashboard Management & Operasional (🟡)

- [x] RPC `admin_metrics` (periode WIB): sesi, operasional, pengguna, revenue, performa tutor,
      progres siswa (sesi selesai + latihan bank soal), honor tertahan
- [x] RPC `admin_correct_booking` (koreksi status + alasan; audit log; tolak bila earning sudah
      masuk payroll / sudah dibayar; earning hanya boleh lewat status completed)
- [x] RPC `admin_transfer_package` (paket antar-tutor, wajib persetujuan siswa + alasan, audit log;
      booking lama tetap snapshot tutor semula)
- [x] Dashboard **Monitoring**: metrik, performa tutor, progres siswa, koreksi 10 sesi terbaru
- [x] Dashboard **Keuangan**: gross settlement, biaya gateway, potongan platform, refund,
      ledger honor, transaksi terbaru
- [x] Laporan voucher: terpakai/dikunci + total diskon per kode
- [x] Paket Sesi: tombol **Pindah tutor**
- [x] Uji SQL (rollback): transfer paket + audit; koreksi ke completed membuat earning & audit;
      koreksi turun dari completed ditolak (guard ledger)
- [x] Uji UI monitoring/keuangan/payroll di browser
- [x] Audit log viewer
- [x] **UI slicing desain admin** (17 Okt): shell sidebar 3 grup + topbar, dark mode, drawer mobile,
      13 layar memakai token desain (Ringkasan, Pantau Kelas, Tutor, Daftar Harga, Paket, Kelas Grup,
      Ruangan, Gaji Tutor, Keuangan, Voucher, Komplain, Bank Soal, Riwayat Aktivitas), login
- [x] Perbaikan query dashboard: laporan voucher pakai `bookings_visible`; komplain + booking
      diambil terpisah agar tidak kena RLS `bookings` (403)
- [x] **UI slicing mobile siswa + tutor** (17 Okt): token tema, bottom nav 5 tab tutor, Beranda
      siswa/tutor, Jadwal, Absensi, Gaji, Profil, Katalog, Paket, Kelas Grup, Bank Soal,
      Booking/Detail sesi, Login/Daftar
- [x] `BookingItem` membawa `studentName` agar jadwal tutor menampilkan nama siswa

## Fase 9 — Notifikasi & Hardening (🟡)

- [x] Skema `device_tokens` + `notifications` (antrean, status pending/sent/failed, read_at)
- [x] Trigger notifikasi: booking confirmed/in_progress/completed/batal, reschedule, komplain,
      payroll paid, langganan aktif
- [x] Edge `send-push` (FCM HTTP v1, JWT service account, `x-cron-secret`) — ter-deploy,
      menunggu env `FIREBASE_SERVICE_ACCOUNT` + `PUSH_CRON_SECRET`
- [x] Mobile: layar **Notifikasi** (inbox + tandai dibaca), ikon lonceng di Beranda
- [x] Rate limit chat 20 pesan/menit per user + cron pembersih harian
- [x] Hardening grant: cabut EXECUTE semua fungsi dari `anon`/PUBLIC; grant `authenticated`
      hanya untuk RPC klien (temuan advisor 41 fungsi → 0)
- [x] `search_path` tetap untuk `group_discount` & `distance_meters`
- [x] Dashboard modul **Audit Log** (filter aksi, 200 terakhir) — teruji di browser
- [ ] FCM di mobile: butuh `google-services.json` + plugin Firebase (belum ada)
- [ ] Jadwalkan `send-push` (pg_cron/pg_net atau scheduler) setelah env diset
- [ ] Backup/restore check + uji beban ringan
- [ ] Rekonsiliasi Midtrans settlement = `payments` (checklist go-live)

## Fase 10 — Chat siswa↔tutor & Moderasi (🟡)

- [x] Migrasi `20261018000035_fase10_chat.sql`: tabel `conversations`, `conversation_messages`,
      `moderation_flags`; RPC `ensure_conversation`, `send_conversation_message`,
      `mark_conversation_read`; view definer `my_conversations`; realtime + backfill chat lama
- [x] Penjaga teks (nomor HP/email/tautan/ajakan bayar luar) di semua teks buatan pengguna;
      chat ditolak **tanpa disensor**, pelanggaran tercatat di `moderation_flags`
- [x] Mobile: tab **Chat** (inbox + lencana unread), ruang chat realtime, centang dibaca,
      pita notifikasi dalam aplikasi, tombol chat dari detail sesi & profil tutor
- [x] Satu percakapan per tutor; chat hanya bisa dimulai setelah ada booking
- [x] Migrasi `20261018000036_fase11_moderasi.sql`: rujukan `ref_table`/`ref_id` pada catatan
      pelanggaran + RPC `admin_review_flag`, `admin_warn_user` (berjejak di `audit_logs`)
- [x] Dashboard modul **Moderasi Chat**: daftar catatan, buka konteks percakapan, tandai
      ditinjau, kirim peringatan, tangguhkan tutor (via `manage-tutor`)
- [x] Uji RLS: admin membaca catatan/pesan; siswa tidak melihat catatan & ditolak RPC admin (42501)
- [ ] Uji layar moderasi di browser dengan akun admin (`admin@kelasxtra.id`)
- [ ] Bersihkan data uji chat (`Woi`, `Ki`, pesan uji) + migrasi chat per-sesi lama
      (`booking_threads`/`thread_messages`, `send_booking_message` masih dipakai dashboard)
- [ ] FCM/notifikasi HP untuk chat (ditunda; sekarang cukup notifikasi dalam aplikasi)
- [ ] Peringatan admin (`moderation.warning`) belum punya tampilan khusus di Notifikasi mobile

### Rombak Beranda siswa (18 Okt 2026)

- [x] Migrasi `20261018000037_tutor_catalog_ringkas.sql`: view `tutor_catalog` ditambah
      `subjects`, `jenjang`, `days`, `modes`, `min_price` (harga **privat 60 menit** termurah
      mengikuti jenjang & mode tutor) — kartu tutor cukup satu query
- [x] Ritme jarak Beranda dari `AppSpacing` (head→isi 16, antar bagian 24, judul→isi 12) +
      ruang atas kepala layar 8; sebelumnya angka lepas 18/22/9/14
- [x] Kartu promo: tinggi 154, radius `AppRadius.lg`, ikon di kanan kicker, judul 2 baris,
      aksi berbentuk pil, indikator halaman jadi pil (aktif 18px)
- [x] Widget baru `TutorShowcaseCard` (212×208): nama, pil rating, mapel + jenjang,
      "Mulai Rp75.000 / 60 mnt", chip hari tersedia (Sen/Rab/Sab + "+n"), CTA "Lihat profil"
- [x] Tautan "Kelas Grup" ganda di bagian Kekuatan dihapus (masih ada di kartu promo);
      kartu "belum ada sesi terjadwal" kini bisa diketuk → Katalog
- [x] Bagian menggeser mendatar dibuat "bleed" sampai tepi layar (dulu terpotong di batas
      margin 20): ListView Beranda/Katalog tanpa padding sisi + helper `sidePad`/`screenSide`
      di `widgets/screen_head.dart`; karusel promo pakai `padEnds: false` + `viewportFraction 0.94`;
      carousel tutor & deretan chip mapel dapat `padding: EdgeInsets.symmetric(horizontal: 20)`
- [x] Terverifikasi di HP: harga & chip hari tampil benar (Andi/Budi Rp75.000, Siti Rp85.000),
      ketuk kartu → detail tutor, kartu promo → Paket; `flutter analyze` bersih & tanpa overflow;
      kartu menyembul ke tepi layar (koordinat kartu 20 → 340 pada lebar 360)
- [ ] Sapuan kecil lanjutan: kartu padanan untuk Katalog (belum dipakai di sana)

### Rombak halaman Cari Tutor / Katalog siswa (18 Okt 2026)

Riset UX dulu (Baymard, Shopify storefront filtering, pola marketplace tutor), lalu disetujui
pemilik: **chip cepat + lembar bawah** untuk filter, dan **Hari tersedia** masuk sebagai filter
(boleh pilih beberapa hari).

- [x] `KatalogFilter` diperluas: `days` (Set<int>) + `sort` (`KatalogSort`: Terbaik / Termurah /
      A–Z) — sebelumnya hanya mapel & mode yang bisa dipilih walau jenjang/rating sudah ada di
      filter state
- [x] `KatalogRepository.fetchTutors`: filter hari via `tutor_availability.day_of_week` (digabung
      dengan filter mode jadi satu query), `minRating` via `gte`, dan urutan: rating desc /
      `min_price` asc (null terakhir) / nama asc — masing-masing dengan urutan kedua sebagai
      pemutus seri agar posisi tidak berubah-ubah
- [x] Lembar bawah filter baru `features/katalog/katalog_filter_sheet.dart`: grup Mapel, Jenjang
      (SD/SMP/SMA), Mode belajar, **Hari tersedia** (boleh banyak), Rating minimum (4.5+/4.8+);
      header dengan "Reset"; filter langsung berlaku; tombol footer menyebut jumlah hasil
      ("Tampilkan N tutor") sehingga siswa tahu dampaknya sebelum menutup
- [x] Lembar "Urutkan" terpisah dari filter supaya mengubah urutan tidak perlu membuka lembar filter
- [x] Chip "filter aktif" yang bisa dilepas satu-satu (badan chip maupun ikon ✕ bisa diketuk) +
      "Hapus semua"; tombol filter menyebut jumlah pilihan aktif ("Filter (2)")
- [x] Tombol `Filter` di atas hasil + chip cepat mapel ("Semua mapel" + daftar mapel) di bawahnya
- [x] `_TutorRow` (baris lama) diganti `TutorListCard` — kartu penuh dengan bahasa visual Beranda:
      nama + pil rating, pendidikan, `Mapel · jenjang`, "Mulai Rp… / 60 mnt", chip hari, "Lihat profil"
      (komponen avatar/pil rating/harga/chip hari dipakai bersama `TutorShowcaseCard`)
- [x] Status kosong: pesan + tombol "Hapus semua filter" (bukan layar buntu); pencarian teks kini
      juga mencocokkan mapel; kerangka pemuatan mengikuti bentuk kartu baru
- [x] Widget bersama `widgets/selectable_chip.dart` (chip filter & chip aktif satu gaya) —
      catatan: `Container(alignment: …)` membuat chip melebar penuh di dalam `Wrap`, jadi chip
      memakai padding vertikal, bukan `alignment`
- [x] Terverifikasi di HP (Redmi 9): "Filter (3)" + chip aktif Online/Sab/Rating 4.8+ → 2 tutor;
      pilih jenjang SD (tidak ada tutor) → 0 hasil & lembar menampilkan "Tampilkan hasil";
      "Hapus semua" & tombol di status kosong memulihkan 3 tutor; chip mapel cepat "Matematika" →
      1 tutor; cari "Budi" → 1 tutor; chip hari "Sel" → 0 hasil (bukti filter hari jalan);
      urutan termurah/A–Z diterima server (`order=min_price.asc.nullslast` diuji langsung ke
      PostgREST); ketuk kartu → detail tutor; `flutter analyze` bersih
- [ ] Urutan belum bisa dibedakan dari tampilan dengan data contoh (harga & rating ketiga tutor
      berurutan sama untuk ketiga mode urut) — akan terlihat saat data tutor bertambah

### Distribusi mobile: dua APK terpisah (18 Okt 2026)

- [x] Flavor Android: `siswa` → `id.kelasxtra.bimbel` (nama "Kelasxtra"),
      `tutor` → `id.kelasxtra.tutor` (nama "Kelasxtra Tutor") — bisa dipasang berdampingan
- [x] `build-apk.sh` & `run-dev.sh` otomatis memilih flavor dari `ENTRY`
      (`lib/main_tutor.dart` → flavor tutor); `MODE=debug` untuk build cepat
- [x] Hasil: `app-siswa-release.apk` / `app-tutor-release.apk`; terpasang & login terpisah di HP
- [ ] Hapus sisa paket lama `com.example.kelasxtra_app` di HP uji
- [ ] Sapuan kecil: sapaan di Beranda sempat menampilkan email saat profil belum termuat

### Model paket-saja: pertemuan mingguan + harga admin (18 Okt 2026)

- [x] Keputusan pemilik: siswa hanya beli paket 4/8/12 pertemuan (tombol "Pesan Sesi"
      dihapus); jadwal dipilih saat membeli (hari + jam + tanggal mulai) dan sistem
      membuat pertemuan mingguan; masa berlaku 1/2/3 bulan mengikuti jumlah pertemuan;
      harga paket ditetapkan admin; bagian tutor tetap 75% harga sesi normal
- [x] Migrasi `20261018000038_paket_harga_dan_jadwal_mingguan.sql` (diterapkan):
      tabel `package_prices` + RLS + unique index aktif; kolom `schedule_day`,
      `schedule_start_time`, `schedule_start_date`, `address` di `package_purchases`;
      unique index `bookings_package_slot_unique`; RPC `set_package_price`,
      `reserve_package_schedule`, `activate_package`, `cancel_package_reservation`;
      `refund_package` dihitung dari pertemuan yang belum berjalan; seed 54 harga paket
- [x] `create-package-snap` (fungsi edge) ditulis ulang: harga dari `package_prices`,
      harga sesi dari `price_matrix`, memanggil `reserve_package_schedule`, memakai ulang
      Snap bila nominal sama; `midtrans-webhook` memanggil `activate_package` saat lunas
      dan `cancel_package_reservation` saat gagal/expired; keduanya sudah di-deploy
- [x] Mobile: `beli_paket_screen` jadi wizard 3 langkah (paket & durasi / jadwal mingguan /
      ringkasan & bayar), `paket_screen` menampilkan jadwal-jumlah-mulai-berlaku-harga,
      detail tutor menampilkan "Beli Paket", `booking_screen` (pesan sesi) dihapus,
      rute `/booking/:id` dihapus; `flutter analyze` bersih, `flutter test` lulus
- [x] Dashboard: halaman baru "Harga Paket" (tab 4/8/12 pertemuan, matriks
      jenjang × durasi × mode, peringatan bila harga < 75% × harga sesi × jumlah,
      riwayat harga lama) terdaftar di grup bisnis
- [ ] Uji di HP: beli paket → pertemuan mingguan muncul di Jadwal; "Lanjutkan bayar"
      dan "Ubah jadwal" bekerja; kuota & masa berlaku benar
- [x] Revisi `docs/brief-implementasi-v2.0.md` (18 Okt): paket-saja pertemuan mingguan +
      harga admin, penjaga teks/chat & Fase 10, kelas grup min 3 tanpa subsidi, langganan
      bulanan manual — dokumen lain (`arsitektur.md`, `erd.md`, `PRD-UI.md`, `RENCANA-DEV.md`)
      masih menyebut model lama
- Catatan: paket `pending_payment` yang kadaluarsa dulu tidak disapu otomatis; bila pembayaran
      masuk setelah lock 30 menit lewat dan slot sudah diambil orang lain, webhook tetap
      mengonfirmasi (sama seperti alur sesi tunggal lama). **Diperbaiki 19 Okt** — lihat
      bagian "Penjaga race slot & pelepasan tahanan".

### Voucher paket + alur setelah pembayaran (18 Okt 2026)

- [x] Migrasi `20261018000039_paket_voucher.sql`: `package_purchases.voucher_id` +
      `discount` (rupiah), `voucher_redemptions.package_purchase_id`, RPC
      `attach/consume/release_voucher_for_package`; `refund_package` memakai uang
      net (setelah diskon). Voucher memakai ulang `check_voucher`/`reserve_voucher`.
- [x] `create-package-snap` menerima `voucher_code`, mengunci kuota, mencatat
      `voucher_id` di payment, nominal = harga paket − diskon; webhook menandai
      terpakai saat lunas dan melepas kuota saat gagal/refund.
- [x] Mobile: input voucher + "Terapkan" di langkah 3, harga coret + baris diskon,
      total bar bawah ikut net.
- [x] Migrasi `20261018000040_tutor_busy_slots.sql`: RPC slot sibuk tutor (semua
      siswa) + milik pemanggil. Wizard menyaring tanggal/jam yang bentrok untuk
      SEMUA pertemuan mingguan; server tetap validasi ulang.
- [x] Error submit tampil sebagai `AlertDialog` (bukan teks kecil).
- [x] Pembayaran: `SnapScreen` memantau status paket dan menutup sendiri saat
      lunas; `PaymentStatusScreen` polling 3 dtk sampai status terminal, refresh
      saat app kembali aktif; layar sukses menampilkan ringkasan paket + CTA
      "Lihat jadwal".
- [x] `flutter analyze` bersih, `flutter test` 23 lulus. Pembayaran sandbox
      terverifikasi: `PKG-149318d5…` settlement, paket `active`, 4 pertemuan dibuat.
- [ ] Uji ulang di HP setelah kabel tersambung: bayar → Snap menutup sendiri →
      layar "Pembayaran berhasil" → "Lihat jadwal".
- [ ] Tombol batal/ubah jadwal per pertemuan paket belum mengembalikan kuota
      (`quota_restored: false`) — perlu keputusan pemilik.
- [x] Bersih-bersih data uji (18 Okt): transaksi/aktivitas/chat/notifikasi/audit
      dihapus, `vouchers.used` direset. Master (akun, tutor, mapel, harga,
      ketersediaan, bank soal) tetap.
- [x] Data dummy sesuai flow paket: 1 paket **aktif** (Andi · Bahasa Inggris SMA,
      4 pertemuan Senin 16:00, lunas Rp340.000, 4 earning tutor) dan 1 paket
      **menunggu bayar** (Budi · Matematika SMA, 8 pertemuan Sabtu 09:00,
      Rp646.000) untuk menguji "Lanjutkan bayar".

### Refactor: pecah layar beli paket (18 Okt 2026)

- [x] `paket/beli_paket_screen.dart` (985 baris) dipecah ke folder
      `paket/beli_paket/`: `beli_paket_screen.dart` (kerangka + navigasi),
      `beli_paket_controller.dart` (state + logika jadwal murni),
      `steps/` (step_paket, step_jadwal, step_ringkasan),
      `widgets/` (step_progress, jadwal_list, bar_total, price_card, voucher_field)
- [x] `flutter analyze` bersih; `flutter test` 27 lulus (4 tes baru: `meetingDates`,
      `nextDates`, `meetingsFree`, `startTimes`)

### Rombak struktur folder mobile (19 Okt 2026)

Kerapian kode menyeluruh: satu folder `widgets/` global dihapus, layar-layar besar
dipecah, kode mati dibuang. Aturan lengkap ada di `docs/arsitektur.md`.

- [x] `lib/widgets/` → `lib/core/widgets/` (komponen lintas fitur). Import diperbarui.
- [x] `app_shell.dart` → `lib/core/app_shell.dart`.
- [x] Widget khas satu fitur dipindah: `section_head.dart` → `features/home/widgets/`,
      `tutor_showcase_card.dart` → `features/katalog/widgets/`,
      `math_text.dart` → `features/bank_soal/widgets/`.
- [x] Hapus kode mati `core/widgets/tutor_card.dart` (0 pemakai).
- [x] `features/home/home_screen.dart` (1165 baris) dipecah: shell pemilih flavor
      (108) + `home/siswa/` (view + widgets) + `home/tutor/` (view + widgets) +
      `home/widgets/` (HomeHead, ClockChip) + `home_utils.dart`.
- [x] Lima layar besar dipecah ke `<fitur>/widgets/`: `booking_detail_screen`
      (561→438), `payment_status_screen` (521→354), `tutor_detail_screen`
      (484→46), `chat_room_screen` (435→284), `bank_soal_screen` (411→112).
- [x] `paket_screen.dart` (289→70) dipecah; `PackageCard` + baris info ke
      `features/paket/widgets/package_card.dart`. `beli_paket/` sudah sesuai
      (screen + controller + steps/ + widgets/).
- [x] Audit kebersihan: tidak ada berkas yang tak pernah di-import; kelas yang
      hanya dipakai dalam satu berkas dijadikan privat; `cleanError()` di
      `core/errors.dart` menggantikan 13 salinan `replaceFirst('Exception: ')`;
      `isSameDay()` di `core/dates.dart` menggantikan 2 salinan pembanding tanggal.
- [x] `flutter analyze` bersih; `flutter test` 27 lulus. Router tidak berubah.

### Rapikan kode dashboard (19 Okt 2026)

Kerapian serupa untuk aplikasi web. Aturan lengkap ada di `docs/arsitektur.md`
("Struktur kode dashboard").

- [x] Utilitas dibagi satu sumber: `lib/format.ts` (`rupiah`, `rupiahCompact`,
      `formatDate`, `formatDateOnly`, `formatDateShort`, `formatDateTime`,
      `formatTime`, `isoDate`) menggantikan 10 salinan `rupiah` + 8 salinan
      formatter tanggal di halaman; `lib/text.ts` (`initials`) menggantikan 3 salinan;
      `lib/functions.ts` (`invokeFn`) menggantikan 2 salinan di Tutors & Moderation.
- [x] Komponen render rumus `MathText` + import KaTeX dipindah dari
      `pages/QuestionCms.tsx` ke `components/MathText.tsx`.
- [x] API mati dibuang: `looksLikeMathExpression` & `toTexExpression` tidak lagi
      di-export (hanya dipakai internal `mathText.ts`).
- [x] Verifikasi: `npm run lint` hanya sisa 6 peringatan lama (Date saat render);
      `npm run build` (`tsc -b` + vite) lulus. Perilaku UI belum diuji di browser.
- [x] 5 halaman besar dipecah ke folder `<Modul>/` (`index.tsx` + komponen bagian
      + `types.ts`), file lama `pages/<Modul>.tsx` dihapus:
      `GroupClasses` 573→`index.tsx` 255 (+types/utils/Form/Summary/Toolbar/Card),
      `Monitoring` 555→248 (+types/Summary/Toolbar/TutorListItem/StudentProgressCard/
      BookingCorrectionCard), `QuestionCms` 458→211 (+types/Form/Table),
      `Payroll` 440→286 (+types/Summary/PeriodRow/PayoutTable),
      `Moderation` 426→204 (+types/FlagsTable/FlagDetailDialog).
      Perbaikan kecil: `canSubmit` di GroupProgramForm kini `Boolean(...)` (dulu
      `string | boolean` → error TS2322); dialog konteks moderasi ditutup lewat ref
      `dialogRef.current?.close()` agar perilaku sama seperti sebelumnya.
- [x] Verifikasi akhir: `npm run build` lulus, `npm run lint` tetap 6 peringatan lama.
- [ ] (Perlu) Uji klik di browser untuk 5 halaman hasil pecah (booking group,
      koreksi absensi, CMS soal, payroll, moderasi) — verifikasi sejauh ini statis saja.

### Penjaga race slot & pelepasan tahanan (19 Okt 2026)

Aturan yang dipakai: slot tutor tidak boleh dobel, dan tahanan slot/kursi hanya boleh
dilepas setelah Midtrans memastikan transaksinya mati (expire/deny/cancel) — bukan
berdasarkan waktu. Jadi tidak ada lagi kemungkinan "sudah bayar tapi slot diambil orang".

- [x] Migrasi `20261019000041_slot_race_guard.sql` (diterapkan ke produksi): `btree_gist` +
      exclusion constraint `bookings_no_tutor_overlap` & `bookings_no_student_overlap`
      (status pengunci: `pending_payment`, `confirmed`, `in_progress`) memakai fungsi
      `public.booking_slot_range(timestamptz, int)` bertanda IMMUTABLE. Catatan teknis:
      `timestamptz + interval` bertanda STABLE sehingga tidak boleh dipakai langsung di
      index expression (error `42P17`); aritmetika memakai epoch agar deterministik.
- [x] Uji nyata di DB produksi (rollback): insert sesi bertumpang ditolak
      (`exclusion_violation`), slot bebas diterima, tidak ada data uji tertinggal
      (bookings tetap 12, tutor/student overlap 0).
- [x] `expire_stale_bookings()` & `expire_stale_group_seats()` jadi perbaikan saja: hanya
      melepas tahanan bila `payments.status` sudah `expire`/`deny`/`cancel`.
- [x] Kolom `payments.review_required` + `review_note` (penanda untuk admin bila ada
      pembayaran yang tidak bisa diselesaikan otomatis), `cancel_dead_package_holds()` +
      cron `cancel-dead-package-holds` (`*/5 * * * *`) untuk paket yang transaksinya mati.
- [x] Edge Function: modul bersama `_shared/paymentApply.ts` (satu sumber logika penerapan
      hasil pembayaran), `midtrans-webhook` v8 memakainya (perilaku sama + penandaan review),
      Edge baru `reconcile-payments` v1 (sapu `payments` pending > 40 menit dengan bertanya
      `GET /v2/{order_id}/status`, tanda review bila Midtrans tak terjangkau > 24 jam).
      Keduanya ter-deploy; uji asap lolos (401 tanpa `x-cron-secret`, 400 body kosong).
- [x] Pesan galat penjaga slot diterjemahkan jadi kalimat ramah di
      `apps/mobile/lib/core/errors.dart` (`cleanError`): "Slot ini baru saja terisi.
      Silakan pilih jam lain, ya." — mencakup dua constraint (<i>exclusion</i>) tadi.
- [x] Tindak lanjut untuk admin: Edge `resolve-payment-review` v1 (khusus admin, JWT
      wajib) + halaman dashboard **Pembayaran Perlu Ditinjau** (modul `payment-reviews`).
      Dua aksi: **Proses ulang** (jalankan ulang aktivasi; bila payment masih `pending`
      status ditanya dulu ke Midtrans) dan **Sudah ditangani** (wajib catatan; dicatat di
      `audit_logs` sebagai `payments.review_dismissed`). Proses ulang aman diulang karena
      semua RPC lanjutan dijaga statusnya; yang berhasil dicatat `payments.review_resolved`.
- [x] `_shared/paymentApply.ts` dirapikan: langkah aktivasi jadi satu fungsi
      (`runSideEffects`) + opsi `force`, dan `outcomeFromPaymentStatus` untuk proses ulang
      tanpa risiko menurunkan status pembayaran yang sudah lunas. `midtrans-webhook` v9 &
      `reconcile-payments` v2 sudah dideploy ulang memakai versi ini.
- [ ] (Perlu) Uji klik halaman Pembayaran Perlu Ditinjau dengan akun admin — belum bisa
      diuji karena belum ada payment bertanda `review_required` di produksi (0 baris).
- [ ] (Perlu) Set `PUSH_CRON_SECRET` lalu jadwalkan `reconcile-payments` tiap 1–5 menit —
      tanpa ini tahanan basi menggantung lebih lama (tidak dobel-booking, tapi slot tertahan).
- [ ] (Perlu) Uji sandbox: bayar paket → lunas; dan biarkan satu tagihan kedaluwarsa →
      slot baru lepas setelah Midtrans bilang `expire`.

### UI Jadwal & Riwayat transaksi (19 Okt 2026)

- [x] Jadwal = agenda sesi saja (uang pindah ke halaman sendiri). Mulanya dikelompokkan
      per tanggal; **sejak 19 Okt sore dikelompokkan per tentor** (lihat bagian
      "Detail Sesi: catatan tentor & tautan Zoom"), kartu sesi baru di
      `features/jadwal/widgets/session_card.dart` — blok jam + tanggal, mapel jadi judul,
      baris `Tutor/Siswa <nama>`, mode + rentang jam WIB, badge status, aksi utama
      (pending → "Bayar sekarang" ke Paket Saya; lainnya "Detail sesi"/"Beri ulasan", dan
      "Gabung Zoom" saat jendela waktu sesi daring terbuka) + "Chat".
- [x] Halaman baru "Riwayat transaksi" (rute `/riwayat-transaksi`, dibuka dari Profil siswa):
      gabungan paket (`package_purchases`), sesi satuan (payment booking), langganan bank soal
      (`subscriptions` + `subscription_plans`), dan kursi kelas grup (`group_seats`),
      dikelompokkan per bulan. Berkas: `features/riwayat/riwayat_repository.dart`,
      `riwayat_providers.dart`, `riwayat_screen.dart`, `widgets/transaksi_tile.dart`.
      Payment paket tidak terbaca siswa lewat `payments` (booking kosong) → dibaca dari
      `package_purchases`.
- [x] Margin atas 20 px seragam: `ScreenHead` (18→20) & `HomeHead` (8→20); layar yang memakai
      `AppBar` (chat room, latihan, hasil, Snap) tidak diubah.
- [x] `flutter analyze` bersih; `flutter test` 27 lulus. Perilaku UI belum diuji di HP.

### Detail Sesi: catatan tentor & tautan Zoom (19 Okt 2026)

Aturan yang dipakai: halaman Detail Sesi **tidak** menampilkan harga/status pembayaran
(uang ada di Riwayat transaksi), catatan tentor wajib terisi sebelum sesi dituntaskan,
dan sesi daring punya tautan Zoom yang hanya terbuka sekitar jam sesi.

- [x] Migrasi `20261019000042_sesi_catatan_zoom.sql` (diterapkan ke produksi, plus
      penyusul `sesi_zoom_guard_mode`): `session_notes.next_step` (tugas/saran
      berikutnya), `bookings.meeting_url` + `meeting_url_set_at`, fungsi
      `public.is_zoom_url()`, trigger `guard_meeting_url` (hanya `https` + host
      `zoom.us`/`zoom.com`, hanya sesi `online`), RPC `set_session_meeting_url`
      (tutor pemilik/admin; mengosongkan tautan juga boleh), `save_session_note`
      diperluas dengan `p_next_step` (3 argumen lama tetap jalan karena default),
      trigger `guard_session_notes` mencakup `next_step`, dan `bookings_visible`
      ditambah kolom `meeting_url` (disembunyikan selama `pending_payment`/`cancelled`/
      `expired`, sama seperti `address`).
- [x] **Temuan penting:** `guard_text` (Fase 10) menolak **semua** tautan — jadi tautan
      Zoom tidak boleh lewat teks bebas (catatan/chat). Karena itu kolom `meeting_url`
      sengaja **tidak** dipasangi `guard_text`; penggantinya validasi domain ketat.
      Tautan juga tidak ditulis ke `audit_logs` (hanya status terisi/kosong).
- [x] Uji nyata di DB produksi (rollback, data 12 booking tetap utuh): tautan non-Zoom
      ditolak, domain palsu (`zoom.us.evil.com`) ditolak, tautan Zoom sah diterima, dan
      menautkan tautan pada sesi `offline` ditolak.
- [x] Aturan jendela waktu di satu tempat: `apps/mobile/lib/core/meeting_link.dart`
      (+ uji `test/meeting_link_test.dart`) — tombol aktif 15 menit sebelum jadwal sampai
      15 menit setelah sesi berakhir; ada keadaan "tentor belum menambahkan tautan".
- [x] UI mobile: `booking_summary.dart` tanpa harga/refund; kartu baru
      `widgets/session_note_card.dart` (materi / perkembangan / tugas-saran berikutnya +
      keadaan kosong) dan `widgets/zoom_join_button.dart`; dialog catatan tentor kini
      3 kolom + tautan Zoom; tombol "Isi catatan lalu selesaikan" mencegah galat
      `complete_booking`; tentor juga bisa mengisi catatan sesi yang tuntas otomatis
      (cron H+1 tidak mewajibkan catatan). Paket `url_launcher` ditambahkan.
- [x] Jadwal kini **dua lapis per orang**: Lapis 1 kartu tentor (foto/inisial, jumlah sesi,
      mapel, sesi berikutnya; untuk tutor Lapis 1 = siswa) yang bisa dibuka-tutup, Lapis 2
      daftar kartu sesinya. Kartu sesi menampilkan tanggal dan berubah jadi "Gabung Zoom"
      saat jendela waktu terbuka.
- [x] `flutter analyze` bersih; `flutter test` 33 lulus (27 lama + 6 baru).

### Kebijakan uang baru: ganti hari berpasangan & poin siswa (19 Okt 2026)

Keputusan pemilik: **tidak ada pengembalian uang dalam bentuk apa pun**. Satu-satunya
pengembalian nilai = **poin** (1 poin = Rp1) yang memotong pembayaran berikutnya.
Siswa tidak bisa membatalkan sesi; ganti hari harus disetujui pihak lain. DB sudah
live; penyesuaian dashboard & mobile sesi dilakukan di sesi ini.

- [x] Migrasi `20261019000043_ganti_hari.sql` (remote `ganti_hari_berpasangan`):
      tabel `reschedule_requests` (1 pending per booking, RLS peserta baca, guard teks),
      helper `tutor_free_at` + `slot_is_free`, RPC `request_reschedule` (≥24 jam sebelum
      sesi, alasan ≥5 huruf, ≤14 hari, dalam masa paket & ketersediaan tutor),
      `respond_reschedule` (pihak lain/admin, re-validasi, pindah jadwal),
      `cancel_reschedule_request`, `expire_reschedule_requests` + cron 10 menit;
      `reschedule_booking` & `cancel_booking` kini **admin-only**, `cancel_booking`
      mengembalikan `{refund_amount: 0, quota_restored}`.
- [x] Migrasi `20261019000044_poin_siswa.sql` (remote `poin_siswa`): ledger
      `student_credits` (+ guard catatan), saldo `student_credit_balance`/`my_credit_balance`,
      `apply_tutor_no_show` + trigger `bookings_after_no_show` (poin = `amount_due` untuk
      sesi satuan, idempoten), `reschedule_no_show` (tutor menjadwalkan ulang pertemuan
      paket no-show, batas 7 hari), `grant_student_credit` (admin), `spend_credits`
      (service_role saja, advisory lock, tolak saldo kurang), `resolve_complaint` →
      `p_credit`/`complaints.credit_nominal`, `cancel_package_with_credit`,
      `cancel_group_seat_with_credit`; `refund_package` & `refund_group_seat` di-drop.
- [x] Catatan penting: `create or replace function` **tidak boleh** mengubah nama
      parameter → `resolve_complaint` lama (4 arg) harus di-drop dulu (galat `42P13`).
      `apply_migration` MCP atomik: percobaan gagal tidak meninggalkan perubahan.
- [x] Migrasi pengetatan `hardening_poin_ganti_hari` (remote saja, tanpa berkas lokal):
      `revoke execute ... from anon` untuk 13 fungsi baru.
- [x] Uji nyata DB dengan blok `DO` + rollback: 11 langkah lulus (pengajuan ganda ditolak,
      pengaju tak bisa menjawab sendiri, terima → pindah jadwal, siswa batal `42501`,
      jadwal di luar ketersediaan ditolak, no-show satuan → poin idempoten, no-show paket →
      notifikasi wajib jadwal ulang, `reschedule_no_show` → `confirmed`, batas 7 hari,
      `spend_credits` + tolak saldo kurang). Data produksi utuh (12 booking, 0 baris uji).
- [x] Dashboard memakai poin: `Packages.tsx` (`cancel_package_with_credit`, label
      "Batalkan → poin", `STATUS_META.refunded` = "Dibatalkan (poin)"), `Disputes.tsx`
      (`p_credit`, kolom "Poin siswa", teks poin), `GroupClasses/index.tsx` +
      `GroupCard.tsx` (`cancel_group_seat_with_credit`, kolom "Poin"), label di
      `registry.ts`; `npm run lint` (hanya peringatan lama) & `npm run build` bersih.
- [x] Mobile: tombol **"Batalkan sesi" dihapus** dan "Ajukan reschedule" →
      **"Ajukan ganti hari"** (`request_reschedule`); kartu baru
      `features/booking/widgets/reschedule_card.dart` (pengaju: "Batalkan pengajuan";
      pihak lain: Terima/Tolak lewat `respond_reschedule`); tutor pada status
      `no_show_tutor` mendapat "Jadwalkan ulang pertemuan" (`reschedule_no_show`);
      saldo poin di Profil siswa (`_PoinCard`, provider `myCreditProvider`).
      `flutter analyze` bersih; `flutter test` 33 lulus.
- [x] **Poin dipakai saat bayar.** Migrasi `20261019000046_poin_checkout.sql`
      (diterapkan): `payments.credit_amount`. Edge Function `_shared/credits.ts`
      (baca saldo + rencana potong) dan `_shared/paymentApply.ts` memotong poin
      lewat `spend_credits` **saat pembayaran lunas** (bukan saat Snap dibuat),
      jadi poin tidak hilang bila bayar kedaluwarsa. `create-package-snap`,
      `create-group-seat-snap`, dan `create-snap` menerima `use_credits`, memotong
      sebanyak mungkin (maks tagihan), dan bila poin menutup seluruh harga →
      **lunas tanpa Midtrans** (`paid: true`). Mobile: `CreditToggle`
      (`core/widgets/credit_toggle.dart`) di layar beli paket & detail kelas grup;
      `SnapResult.paid/creditApplied`; jalur lunas-poin langsung menampilkan
      konfirmasi tanpa membuka Snap. `flutter analyze` bersih; 33 tes lulus;
      typecheck Edge via harness tsc bersih.
- [x] **6 Edge Function dideploy ke produksi** (disetujui pemilik):
      `supabase functions deploy create-snap create-package-snap
      create-group-seat-snap midtrans-webhook reconcile-payments
      resolve-payment-review`. Fungsi menjawab (401 tanpa JWT) dan data produksi
      utuh (12 booking, 2 payment, 0 poin, 0 permintaan ganti hari).
- [x] Berkas lokal migrasi pengetatan `20261019000045_hardening_poin_ganti_hari.sql`
      dibuat (isinya dicocokkan dengan tanda tangan fungsi asli di DB).
- [x] **Migrasi pembayaran Snap → QRIS dinamis (Core API), belum di-deploy.**
      `_shared/midtrans.ts`: `createSnap`/`snapBase` dihapus → `createQris(orderId,
      amount, itemName, customer)` (POST `/v2/charge`, `payment_type: qris`,
      `acquirer: gopay`, `custom_expiry` = `LOCK_MINUTES` 30 menit) mengembalikan
      `{qr_string, qr_url, expires_at}`; helper `Qris`, `cachedQris`, `qrisFields`
      (respons tetap mengisi `redirect_url = qr_url` agar APK lama jalan). Empat
      Edge (`create-snap`, `create-package-snap`, `create-group-seat-snap`,
      `create-subscription-snap`) memakai `createQris` dan menyimpan objek QRIS di
      `payments.raw`; **QRIS lama selalu dipakai ulang** selama baris `payments`
      masih `pending` (tagihan terkunci, karena Midtrans menolak charge kedua
      dengan `order_id` sama). Webhook & `paymentApply` tidak diubah.
      Mobile: `qris_screen.dart` baru (QR `qr_flutter`, hitung mundur, polling
      `my_payment_status` tiap 3 detik + saat app kembali aktif, tombol "Saya sudah
      bayar"), `snap_screen.dart` dihapus (5 pemanggil pindah), `SnapResult` kini
      `qrString/qrUrl/expiresAt` + `fromJson`, `pubspec` tambah `qr_flutter ^4.1.0`
      dan buang `webview_flutter`. Migrasi `20261019000047_my_payment_status.sql`
      (belum diterapkan): RPC definer yang hanya mengembalikan status payment milik
      `auth.uid()`. `flutter analyze` bersih; 33 tes lulus; typecheck Edge (harness
      tsc, 7 fungsi) bersih.

## Langkah berikutnya

0. **Migrasi QRIS (menunggu izin pemilik)**: terapkan migrasi
   `20261019000047_my_payment_status.sql` (lewat MCP `apply_migration`, **bukan**
   `supabase db push` — riwayat migrasi remote memakai versi timestamp dari MCP,
   jadi `db push` akan menganggap 43–47 belum jalan) lalu deploy
   `supabase functions deploy create-snap create-package-snap
   create-group-seat-snap create-subscription-snap reconcile-payments`. Setelah itu
   uji sandbox: bayar QRIS Simulator → webhook → `payments.status = settlement` →
   `QrisScreen` menutup sendiri; uji juga QR dipakai ulang, QR kedaluwarsa, dan
   lunas penuh oleh poin (tanpa QrisScreen).
1. Uji pemakaian poin end-to-end dengan akun siswa berpoin: (a) potong sebagian
   (bayar sisa via Midtrans), (b) potong penuh → lunas tanpa Midtrans. Beri poin uji
   lewat komplain (`resolve_complaint`) atau `grant_student_credit` sebagai admin.
1. Uji di HP: Detail Sesi (tanpa harga, catatan tentor, tambah tautan Zoom, tombol
   "Gabung Zoom" saat waktunya) dan Jadwal dua lapis per tentor. HP belum terdeteksi
   (`flutter devices` kosong) — sambungkan ulang lalu `./run-dev.sh e68890180406`.
2. Set `FIREBASE_SERVICE_ACCOUNT` + `PUSH_CRON_SECRET`, pasang config Firebase Android, uji push.
3. Jadwalkan pemanggilan `send-push` **dan** `reconcile-payments` tiap 1–5 menit
   (header `x-cron-secret`).
4. Backup/restore check (`supabase db dump`) + uji beban ringan.
5. Rekonsiliasi pembayaran Midtrans vs tabel `payments`; lengkapi checklist go-live.
6. Set secret email/SMTP Resend (masih pending).
