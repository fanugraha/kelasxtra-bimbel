# Konteks Proyek Kelasxtra Bimbel

> Catatan ini adalah **pintu masuk (hub)** proyek. Mulai dari sini, lalu ikuti tautan.

## Konteks

Marketplace bimbel (Jogja) dengan **dua produk independen**:
1. Langganan bank soal — Rp29.000/bulan, Midtrans recurring.
2. Paket sesi bimbel — privat & grup (maks 5), bayar sekali via Midtrans Snap.

Detail: [[2026-10-15-setup-fase-0-fondasi]] · [[2026-10-15-keputusan-teknis-kelasxtra]]

Dokumen resmi proyek ada di folder `docs/` repo:
- Acuan kerja: `docs/brief-implementasi-v2.0.md` (**brief v2.0 menang**)
- PRD lama: `docs/prd-v1.0.md`
- Arsitektur: `docs/arsitektur.md` · Data: `docs/erd.md` · Progres: `docs/PROGRES.md`

## Keputusan atau temuan

- Brief v2.0 (15 Okt 2026) berbeda dari PRD v1.0. Brief menang: tutor **diundang admin** (bukan self-signup), **tanpa upload KTP**, pembayaran tutor = **payroll bulanan** (bukan dompet + tarik dana), ada **voucher** + **kelas grup** di MVP.
- Dokumen referensi penuh `bimbel-rancangan-produk.md` (ERD 29 tabel) **belum ditemukan**. ERD disusun ulang dari brief → `docs/erd.md`.
- Struktur: monorepo `apps/mobile` (Flutter, 2 flavor), `apps/dashboard` (React+TS+Vite), `supabase/`, `docs/`, `catatan/`.

## Alasan

- Satu codebase Flutter dipakai dua aplikasi (siswa & tutor) lewat flavor/entry point — hemat perawatan.
- Harga sebagai data (`price_matrix`), bukan hardcode, agar perubahan bisnis tak perlu rilis app.

## Langkah berikutnya

- Fase 1: alur undangan tutor + aktivasi. Lihat `docs/PROGRES.md`.
- Validasi `supabase db reset` (butuh Docker) dan uji RLS akses silang.

## Tautan terkait

- [[2026-10-15-rencana-pengembangan]]
- [[2026-10-15-keputusan-teknis-kelasxtra]]
- [[2026-10-15-setup-fase-0-fondasi]]
- [[2026-10-15-tooling-mcp-library]]
