# Fase 5 — Bank Soal (progres & keputusan)

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

17 Okt 2026. Bank soal = produk kedua: langganan bulanan untuk latihan per topik + tryout +
analisis. Brief menyebut "Midtrans recurring" (potong otomatis).

## Keputusan

- **Cara bayar langganan = C (campuran), mulai dari manual bulanan.**
  Potong otomatis hanya bisa untuk metode yang bisa ditoken (kartu/e-wallet tertentu) —
  **QRIS & transfer bank tidak bisa**. Target kita mayoritas QRIS/e-wallet, jadi memaksa
  auto-recurring akan mematikan akses sejak hari pertama.
  - Fase ini: **bayar bulanan manual via Snap** + **tenggang 3 hari**.
  - Auto-potong kartu menyusul; kolom `subscriptions.midtrans_subscription_id` + `auto_renew`
    sudah disiapkan (tak perlu bongkar skema).
- Harga di tabel `subscription_plans`: `bank_soal`, **Rp29.000 / 30 hari**, tenggang 3 hari.
- **Kunci jawaban tak pernah bocor ke client**: soal lewat RPC `start_attempt`
  (body + opsi + gambar saja), penilaian di `submit_attempt` (server).
- Statistik diperbarui **saat submit** (bukan job) → DoD "analisa ≤1 menit" otomatis.
- Alur soal: `draft → review → published → archived`; mengedit = **versi baru**
  (`question_versions`), riwayat tak rusak.

## Selesai & teruji

- **Bagian 1 (DB)** — commit `c5c918b`: skema `subscription_plans`, `subscriptions`,
  `questions`, `question_versions`, `attempts`, `attempt_answers`, `student_topic_stats` + RLS;
  RPC `start_attempt` / `submit_attempt`; cron `refresh_subscription_statuses`.
  Uji: kunci tak bocor; 2/3 benar → akurasi 66.67%; langganan nonaktif → ditolak.
- **Bagian 2 (CMS dashboard)** — commit `b1a0c18`: halaman CMS soal (KaTeX `$...$`, upload gambar ke
  `question-assets`, daftar + filter, aksi status, riwayat versi); RPC `admin_save_question`
  (edit → versi baru) & `admin_set_question_status` (+audit); view `questions_admin`
  (security_invoker → siswa 0 baris). Build lolos.
- **Bagian 3 (backend langganan)** — commit `bb3181c`: `payments.subscription_id`;
  Edge `create-subscription-snap`; RPC `activate_subscription` (perpanjang dari tanggal
  berakhir yang berlaku); webhook cabang `subscription`. Uji: beli 29.000 → settlement →
  langganan aktif s/d +30 hari, tenggang +3.

## Status verifikasi (17 Okt, lanjutan)

**Bagian 3 (mobile) TERVERIFIKASI statis:** `flutter analyze` bersih (0 issue),
`flutter test` 12/12 lulus. Dua temuan diperbaiki: import `async_view` tak terpakai di
`latihan_screen.dart`, dan error submit yang tertelan (`_error` diset tapi tak pernah
ditampilkan) — kini muncul lewat SnackBar.

Belum: build APK + uji alur di HP, lalu commit.

## Tryout (3a) — selesai 17 Okt

`LatihanScreen` kini punya `mode` + `durationMinutes`: timer 20 menit (format
`AppFormat.clock`), auto-submit saat habis, auto-submit hanya sekali (`_submitting`),
timer dibatalkan saat layar ditutup. Rute `/tryout`: 20 soal acak, **difilter jenjang siswa**
(diambil dari `myProfileProvider`). CTA "Tryout" di layar Bank Soal (terkunci bila langganan
nonaktif). Jawaban yang belum diisi tetap dikirim sebagai `null` → dihitung salah, masuk
pembahasan. Statis: analyze 0 issue, test 12/12 (termasuk 3 assert `AppFormat.clock`).

Sisa: auto-potong kartu (Midtrans recurring), build APK + uji HP.

File (sudah di-commit WIP `adfface`):
- `apps/mobile/lib/features/bank_soal/bank_soal_repository.dart` (plan, langganan, start/submit attempt, stats, signed image)
- `apps/mobile/lib/features/bank_soal/bank_soal_providers.dart`
- `apps/mobile/lib/features/bank_soal/bank_soal_screen.dart` (status langganan + CTA + topik + "Fokus Perbaikimu")
- `apps/mobile/lib/features/bank_soal/latihan_screen.dart` (satu soal per layar + submit)
- `apps/mobile/lib/features/bank_soal/hasil_screen.dart` (nilai + pembahasan)
- `apps/mobile/lib/widgets/math_text.dart` (render `$...$` via `flutter_math_fork`)
- diubah: `core/router.dart` (`/bank-soal`, `/latihan/:topicId`), `features/home/home_screen.dart`
  (aksi cepat **Bank Soal**), `pubspec.yaml` (`flutter_math_fork`)

## Langkah berikutnya (saat lanjut)

1. `flutter build apk --release -t lib/main_siswa.dart --dart-define=…` lalu `adb install -r`
   (HP: `e68890180406`; APK juga ada di `build/app/outputs/flutter-apk/`).
2. Uji alur di HP: **Bank Soal** → status langganan (siswa demo sudah aktif s/d 16 Des) →
   pilih topik *Trigonometri* → kerjakan → lihat hasil + pembahasan → cek analisa
   ("Fokus Perbaikimu") terbarui.
3. Commit hasil 5c (termasuk perbaikan analyze).
4. Sisa Fase 5 (opsional): **tryout** (timer) & **auto-potong kartu**.

## Jebakan yang sudah ditemukan

- Midtrans membatasi **`order_id` ≤ 50 karakter** (order langganan semula 54 → ditolak).
- Soal/opsi memakai `$...$`; di **dashboard** dirender KaTeX, di **mobile** dengan
  `flutter_math_fork` (`lib/widgets/math_text.dart`).

## Tautan terkait

- [[2026-10-16-fase-4-kelas-grup]]
- [[2026-10-15-rencana-pengembangan]]
