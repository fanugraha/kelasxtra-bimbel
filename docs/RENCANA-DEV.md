# Rencana Pengembangan Kelasxtra Bimbel

Acuan kerja: [brief-implementasi-v2.0.md](brief-implementasi-v2.0.md).
Status berjalan: [PROGRES.md](PROGRES.md). Arsitektur: [arsitektur.md](arsitektur.md).

> Estimasi di bawah **relatif** (S/M/L), bukan janji tanggal. Ukuran: S ≤ 3 hari,
> M 4–10 hari, L > 10 hari kerja satu orang. Kalikan bila sambil kerja/mengajar.

---

## 1. Prinsip

1. **Kerjakan berurutan** Fase 0→9. Tiap fase berakhir dengan demo + Definition of Done (DoD).
2. **Tiap fase menambah migrasi baru**, bukan mengubah migrasi lama (kecuali bug).
3. **Uji RLS di setiap fase** (siswa A ≠ siswa B; tutor hanya lihat siswanya).
4. **Tidak membangun hal di luar scope** (lihat bagian 8 brief).
5. **Uang & waktu** mengikuti konvensi (integer rupiah; UTC disimpan, WIB tampil).

## 2. Prasyarat & akun (lakukan sekali)

| Kebutuhan | Detail | Dipakai fase |
|---|---|---|
| Supabase project (cloud, dev) | 1 project dev terpisah dari prod | 0+ |
| Supabase CLI + Docker lokal | `supabase start` untuk dev tanpa kuota | 0+ |
| Midtrans Sandbox | Server Key, Client Key, webhook URL | 2 |
| Firebase project | `google-services.json`, `GoogleService-Info.plist` | 9 |
| Google OAuth (opsional) | login Google | 1 |
| Repo GitHub + Actions | CI sudah ada | 0+ |

**Rahasia (jangan commit):**

```bash
# Client/build
SUPABASE_URL, SUPABASE_ANON_KEY         # mobile --dart-define, dashboard .env
# Edge Functions (server-only)
supabase secrets set MIDTRANS_SERVER_KEY=... MIDTRANS_CLIENT_KEY=... MIDTRANS_IS_SANDBOX=true
supabase secrets set FCM_SERVICE_ACCOUNT=...   # atau kredensial FCM
# MCP (lokal, untuk agent)
export SUPABASE_ACCESS_TOKEN=... GITHUB_PERSONAL_ACCESS_TOKEN=...
```

## 3. Keputusan yang harus diputus sebelum fase terkait

| # | Keputusan | Status (brief v2.0) | Fase |
|---|---|---|---|
| O1 | Minimal peserta kelas grup | **Terjawab**: min **3** siswa, **tanpa subsidi**; bayar sekali per kursi; tenggat H-1 20:00 WIB; jika <3 program batal (pindah kelas/kredit dulu, lalu refund penuh). Cap 2 slot/minggu dibuang | 4 |
| O2 | Kebijakan pembatalan | **Terjawab**: <24 jam 50%/kuota hangus; >24 jam penuh | 6 |
| O3 | Siklus payout | **Terjawab**: bulanan, cut-off tgl 25 | 7 |
| O4 | Pembulatan 75/25 | **Terjawab**: `floor` ke rupiah | 2 |
| O5 | Konfirmasi selesai | **Terjawab**: auto-complete H+1 tanpa komplain | 6 |
| O6 | Tenggang langganan gagal bayar | **Terjawab**: 3 hari | 5 |
| O7 | Harga final price matrix | **Belum** — seed masih placeholder | 2 |
| O8 | Webhook/domain dashboard | **Belum** — perlu URL publik untuk callback | 2 |

> O7, O8 memblokir fase 2 (O8 sudah diputus: webhook pakai URL Edge Function). Putuskan sebelum mulai fase itu.

## 4. Roadmap per fase

| Fase | Deliverable utama | Effort | Prasyarat | Status |
|---|---|---|---|---|
| 0 | Fondasi: monorepo, auth, RLS | M | — | 🟡 |
| 1 | Akun & profil (undangan tutor) | M | 0 | ⬜ |
| 2 | Katalog + booking privat + Midtrans | L | 1, O7, O8 | ⬜ |
| 3 | Paket sesi (kredit) | M | 2 | ⬜ |
| 4 | Kelas grup | M | 2, O1 | ⬜ |
| 5 | Bank soal + analisis | L | 1 | ⬜ |
| 6 | Absensi, reschedule, komplain, pesan | L | 2–4 | ⬜ |
| 7 | Payroll bulanan | M | 6 | ⬜ |
| 8 | Dashboard management | L | 2–7 | ⬜ |
| 9 | Notifikasi & hardening | M | semua | ⬜ |

### Fase 0 — Fondasi ✅/🟡
Selesai kecuali: validasi `supabase db reset`, uji RLS, akun admin pertama.
**Tutup dulu:** jalankan Supabase lokal, buat akun admin via SQL/service role.

### Fase 1 — Akun & Profil (M)
Migrasi: `tutors` (kini) diperluas (`invite_token` sudah ada).
Edge Functions: `invite-tutor` (buat akun auth + kirim link, exp 7 hari), `send-email`.
Mobile: aktivasi tutor (set password + profil + data bank), profil siswa.
Dashboard: modul **Tutor & Undangan** — buat akun, kirim ulang undangan, suspend/reaktivasi.
DoD: admin buat tutor → tutor aktivasi → profil tayang di katalog, end-to-end.

### Fase 2 — Katalog & Booking Privat (L)
Migrasi: `tutor_availability`, `bookings`, `payments`, `audit_logs`.
Edge Functions: `create-snap`, `midtrans-webhook` (idempoten + signature SHA512).
Mobile siswa: katalog (filter mapel/jenjang/harga/rating), profil tutor, pilih slot →
ringkasan (harga snapshot) → voucher input → Snap → status.
Aturan: slot lock 30 mnt (`lock_expires_at`), auto-accept, alamat terbuka pasca-bayar.
Dashboard: modul **Price Matrix** (CRUD + riwayat), **Voucher** (CRUD + kuota race-safe).
DoD: booking sukses, gagal, dan timeout tertangani; webhook duplikat tidak dobel.

### Fase 3 — Paket Sesi (M)
Migrasi: `package_purchases`.
Aturan kredit: `sesi_terpakai` ≤ `total_sesi`; booking ≤ `expires_at` (90 hari);
diskon 4/8/12 = 0/5/10%; terikat 1 tutor.
Mobile: beli paket, sisa kuota, booking pakai kuota tanpa bayar per sesi.
Editorial: tulis eksplisit "kuota kedaluwarsa hangus" di checkout. Admin: refund proporsional.
DoD: beli → pakai → habis → refund parsial benar.

### Fase 4 — Kelas Grup (M)
Migrasi: `group_classes`, `group_seats`, `rooms`.
Aturan: kapasitas 5, honor = 75% × (harga × kursi terbooking), no-show tetap dihitung,
min 1 peserta jalan (subsidi s/d setara 3 kursi), maks 2 slot/tutor/minggu.
Dashboard: buat slot, assign tutor, ruangan (anti double-booking), pantau keterisian.
DoD: 5 kursi penuh & kasus 1 peserta (subsidi) benar. **Butuh O1.**

### Fase 5 — Bank Soal + Analisis (L)
Migrasi: `subscriptions`, `questions`, `question_versions`, `attempts`, `attempt_answers`,
`student_topic_stats`.
Edge Functions: `midtrans-recurring-webhook`, job tenggang 3 hari.
Dashboard: **CMS soal** (KaTeX + gambar, tag, versioning, draf→review→tayang).
Mobile: langganan, latihan per topik, tryout (timer opsional), pembahasan, grafik skor,
dashboard "Fokus Perbaikimu".
DoD: langganan aktif → latihan → analisa terupdate ≤ 1 menit.

### Fase 6 — Absensi, Reschedule, Komplain, Pesan (L)
Migrasi: `booking_reschedules`, `session_notes`, `reviews`, `complaints`,
`booking_threads`, `thread_messages`, `tutor_earnings`.
Edge/cron: auto-complete H+1 (pg_cron), geofence 200 m, filter nomor telepon.
Aturan: reschedule atomik (tanpa ganti mode, maks 14 hari), komplain H+3, refund <24 jam.
DoD: semua skenario absen/no-show/reschedule/komplain lolos uji.

### Fase 7 — Payroll Bulanan (M)
Migrasi: `payouts`.
Ledger append-only (`belum_dibayar → ditahan → sudah_dibayar`).
Dashboard: rekap per periode (cut-off tgl 25) → four-eyes approval → ekspor transfer →
"tandai sudah ditransfer". Mobile tutor: slip (tanpa tombol tarik).
DoD: simulasi 1 bulan (1 komplain + 1 no-show) angka klop.

### Fase 8 — Dashboard Management (L)
Modul: monitoring (progres siswa, performa tutor, operasional harian), keuangan
(gross, potongan 25%, estimasi gateway), ruangan, koreksi absensi (audit log),
migrasi paket antar-tutor, laporan voucher.
DoD: semua modul jalan dengan data nyata fase sebelumnya.

### Fase 9 — Notifikasi & Hardening (M)
FCM: konfirmasi, H-1 & 1 jam sebelum, pembayaran, reschedule, payroll.
Rate limiting, audit log lengkap, backup/restore check, uji beban ringan, perbaikan bug.
DoD: checklist go-live (bagian 5) terpenuhi.

## 5. Checklist Go-Live (MVP)

- [ ] Fase 0–9 selesai + didemo
- [ ] Rekonsiliasi Midtrans settlement = `payments` tercatat
- [ ] Simulasi payroll 1 bulan angka klop (1 komplain + 1 no-show)
- [ ] RLS diuji lintas user
- [ ] Webhook: sukses, gagal, duplikat (idempoten) teruji
- [ ] Konsultasi hukum (penahanan dana) & akuntan (pajak tutor)
- [ ] SOP operasional disosialisasikan
- [ ] Keputusan O1, O7, O8 diputus

## 6. Risiko teknis & mitigasi

| Risiko | Mitigasi |
|---|---|
| Webhook dobel/gagal | idempotency by `order_id` + rekonsiliasi berkala |
| Race kuota voucher/paket | kunci di server (transaksi DB), bukan validasi client |
| Kebocoran kolom bank tutor ke katalog | VIEW publik tanpa kolom sensitif sebelum Fase 2 (sudah ditandai di migrasi tutors) |
| Flutter 2 flavor menyimpang | widget/logika bersama di `lib/shared`, perbedaan hanya di router/beranda |
| Biaya gateway menggerus margin | dilaporkan terpisah, tidak memotong bagi hasil tutor |
| Firebase belum siap → build Android gagal | setup Firebase sebelum Fase 9 (dep sudah terpasang) |

## 7. Urutan pengerjaan singkat

```
0 (tutup) → 1 → 2 → 3 ┐
                      ├→ 6 → 7 → 8 → 9
        1 → 5 ────────┘
                      └→ 4 (butuh 2)
```

Fase 5 (bank soal) bisa jalan paralel dengan 3–4 karena independen setelah Fase 1.
