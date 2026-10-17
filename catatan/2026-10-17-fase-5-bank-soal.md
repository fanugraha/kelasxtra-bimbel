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

## BELUM SELESAI — berhenti di sini (17 Okt)

**Bagian 3 (mobile) sudah DITULIS tapi BELUM DIVERIFIKASI.** `flutter analyze` belum
dijalankan (sesi dihentikan), jadi **mungkin masih ada error kompilasi**.

File (belum di-commit sebelum catatan ini):
- `apps/mobile/lib/features/bank_soal/bank_soal_repository.dart` (plan, langganan, start/submit attempt, stats, signed image)
- `apps/mobile/lib/features/bank_soal/bank_soal_providers.dart`
- `apps/mobile/lib/features/bank_soal/bank_soal_screen.dart` (status langganan + CTA + topik + "Fokus Perbaikimu")
- `apps/mobile/lib/features/bank_soal/latihan_screen.dart` (satu soal per layar + submit)
- `apps/mobile/lib/features/bank_soal/hasil_screen.dart` (nilai + pembahasan)
- `apps/mobile/lib/widgets/math_text.dart` (render `$...$` via `flutter_math_fork`)
- diubah: `core/router.dart` (`/bank-soal`, `/latihan/:topicId`), `features/home/home_screen.dart`
  (aksi cepat **Bank Soal**), `pubspec.yaml` (`flutter_math_fork`)

## Langkah berikutnya (saat lanjut)

1. `cd apps/mobile && flutter analyze` → perbaiki error (kemungkinan kecil: tipe/import).
2. `flutter test` (harus tetap 12/12).
3. `flutter build apk --release -t lib/main_siswa.dart --dart-define=…` lalu `adb install -r`
   (HP: `e68890180406`; APK juga ada di `build/app/outputs/flutter-apk/`).
4. Uji alur di HP: **Bank Soal** → status langganan (siswa demo sudah aktif s/d 16 Des) →
   pilih topik *Trigonometri* → kerjakan → lihat hasil + pembahasan → cek analisa
   ("Fokus Perbaikimu") terbarui.
5. Commit hasil 5c.
6. Sisa Fase 5 (opsional): **tryout** (timer) & **auto-potong kartu**.

## Jebakan yang sudah ditemukan

- Midtrans membatasi **`order_id` ≤ 50 karakter** (order langganan semula 54 → ditolak).
- Soal/opsi memakai `$...$`; di **dashboard** dirender KaTeX, di **mobile** dengan
  `flutter_math_fork` (`lib/widgets/math_text.dart`).

## Tautan terkait

- [[2026-10-16-fase-4-kelas-grup]]
- [[2026-10-15-rencana-pengembangan]]
