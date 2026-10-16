# Rencana Pengembangan

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

Menyusun rencana dev bertahap untuk aplikasi. Disimpan di `docs/RENCANA-DEV.md`.

## Keputusan atau temuan

- Urutan fase 0→9 dari brief dipertahankan, ditambah **prasyarat akun**, **keputusan
  terbuka**, **Definition of Done tiap fase**, **estimasi relatif (S/M/L)**, dan **risiko**.
- **Blocker yang tersisa**: O1 (min peserta kelas grup), O7 (harga final price matrix),
  O8 (URL webhook/domain). O2–O6 sudah terjawab oleh brief v2.0.
- Fase 5 (bank soal) **independen** setelah Fase 1 → bisa dikerjakan paralel dengan 3–4.
- Prasyarat eksternal: Midtrans Sandbox (Fase 2), Firebase (Fase 9).

## Alasan

- Estimasi relatif dipakai karena dikerjakan sendiri, bukan tim — hindari janji tanggal semu.
- DoD per fase mencegah "setengah jadi" menumpuk sebelum go-live.

## Langkah berikutnya

- Tutup Fase 0: validasi `supabase db reset` + buat akun admin pertama + uji RLS.
- Putuskan O7 (harga) dan O8 (webhook) sebelum mulai Fase 2.
- Mulai Fase 1 (undangan tutor).

## Tautan terkait

- [[2026-10-15-konteks-proyek-kelasxtra-bimbel]]
- [[2026-10-15-setup-fase-0-fondasi]]
- [[2026-10-15-keputusan-teknis-kelasxtra]]
