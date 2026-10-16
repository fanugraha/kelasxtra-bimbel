# Kelasxtra Bimbel

Marketplace bimbel dengan dua produk independen:
1. **Langganan bank soal** — Rp29.000/bulan, Midtrans recurring.
2. **Paket sesi bimbel** — privat & grup (maks 5), bayar sekali via Midtrans Snap.

Referensi lengkap ada di [`docs/`](docs/). Brief kerja: `docs/brief-implementasi-v2.0.md`.

## Struktur

```
apps/mobile      Flutter — SATU codebase, DUA flavor (siswa & tutor)
apps/dashboard   Web admin (React + TypeScript + Vite)
supabase         migrations (SQL versioned), functions (Edge), seed.sql
docs             PRD, arsitektur, ERD, catatan keputusan
catatan          memori kerja (disalin otomatis ke vault saat sesi ditutup)
```

## Status

Fase 0 (fondasi) — auth + RLS + skeleleton. Lihat [`docs/PROGRES.md`](docs/PROGRES.md)
dan rencana pengembangan [`docs/RENCANA-DEV.md`](docs/RENCANA-DEV.md).

## Prasyarat

- Flutter (stable), Node 20+, Supabase CLI, Docker (untuk Supabase lokal).

## Supabase (lokal)

```bash
supabase start                 # butuh Docker menyala
supabase db reset              # jalankan migrations + seed.sql
supabase status                # ambil API URL + anon key
```

Migrasi ada di `supabase/migrations/` (versioned, jangan ubah via dashboard di prod).
Uang selalu integer rupiah; waktu disimpan UTC; RLS deny-by-default.

## Mobile

```bash
cd apps/mobile
flutter pub get
flutter run -t lib/main_siswa.dart \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
# flavor tutor:
flutter run -t lib/main_tutor.dart --dart-define=...
```

## Dashboard

```bash
cd apps/dashboard
cp .env.example .env           # isi VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
npm install
npm run dev
```

## Uji & lint

```bash
cd apps/mobile && flutter analyze && flutter test
cd apps/dashboard && npm run lint && npm run build
```

## Perkakas: MCP & skill

MCP dipasang di config global `~/.config/opencode/opencode.jsonc` (supabase, context7,
playwright, github). **Restart opencode** setelah mengubahnya. Ekspor rahasia lebih dulu:

```bash
export SUPABASE_ACCESS_TOKEN=...          # Supabase > Account > Access Tokens
export GITHUB_PERSONAL_ACCESS_TOKEN=...   # GitHub > Settings > Developer settings
```

Skill proyek: `.opencode/skills/kelasxtra-bimbel/SKILL.md` (aturan kerja, otomatis aktif).

## Aturan bisnis kritis

Lihat bagian 4 `docs/brief-implementasi-v2.0.md`. Ringkas: slot auto-accept,
uang integer, harga di-snapshot, RLS deny-by-default, webhook idempoten,
ledger append-only, payroll bulanan (cut-off tgl 25).
