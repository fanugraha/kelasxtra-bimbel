# Fase 5 — Bank Soal (keputusan & bagian 1)

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

17 Okt 2026. Bank soal = produk kedua: langganan untuk latihan per topik + tryout +
analisis. Brief menyebut "Midtrans recurring" (potong otomatis).

## Keputusan atau temuan

- **Cara bayar langganan = C (campuran), mulai dari manual bulanan.**
  Alasan: potong otomatis **hanya** bisa untuk metode yang bisa ditoken (kartu kredit/debit,
  GoPay/ShopeePay) — **QRIS & transfer bank tidak bisa**. Target kita (siswa SMA & orang tua)
  lebih banyak pakai QRIS/e-wallet, jadi memaksa auto-recurring akan mematikan akses
  berlangganan sejak hari pertama.
  - Fase ini: **bayar bulanan manual via Snap** + **tenggang 3 hari** setelah periode habis.
  - Auto-potong kartu (Midtrans Subscription API) menyusul tanpa membongkar skema
    (`subscriptions.midtrans_subscription_id` + `auto_renew` sudah disiapkan).
- **Harga di tabel** `subscription_plans` (bukan hardcode): `bank_soal`, Rp29.000 / 30 hari,
  tenggang 3 hari.
- **Kunci jawaban tidak pernah bocor ke client.** Soal diberikan lewat RPC `start_attempt`
  (hanya body + opsi + gambar), penilaian di `submit_attempt` (server). Ini syarat utama
  bank soal; tidak boleh ada `select` langsung ke `question_versions` dari siswa.
- **Statistik diperbarui saat submit** (bukan job terjadwal) → DoD "analisa terupdate ≤1 menit"
  otomatis terpenuhi.
- Alur soal: `draft → review → published → archived`; mengedit membuat **versi baru**
  (`question_versions`), riwayat tak rusak.

## Bagian 1 (selesai & teruji)

- Skema: `subscription_plans`, `subscriptions`, `questions`, `question_versions`, `attempts`,
  `attempt_answers`, `student_topic_stats` + RLS (siswa hanya lihat miliknya).
- RPC: `start_attempt` (gerbang langganan aktif/grace, soal acak tanpa kunci),
  `submit_attempt` (nilai + update akurasi, 20-terakhir, tren).
- Cron `refresh_subscription_statuses`: `active → grace → expired`.
- Uji: 3 soal published; latihan 2/3 benar → akurasi 66.67%, 20-terakhir 2/3, tren `null`
  (butuh ≥5); langganan nonaktif → ditolak.

## Langkah berikutnya

- Bagian 2: CMS soal di dashboard (KaTeX + gambar, tag, draf→review→tayang).
- Bagian 3: mobile — langganan + latihan per topik + pembahasan + skor + "Fokus Perbaikimu".
- Bagian 4: tryout (timer opsional) & auto-potong kartu (opsional).

## Tautan terkait

- [[2026-10-16-fase-4-kelas-grup]]
- [[2026-10-15-rencana-pengembangan]]
