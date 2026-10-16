# Keputusan Teknis Kelasxtra Bimbel

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

Menetapkan fondasi teknis (Fase 0) sesuai brief v2.0.

## Keputusan atau temuan

| Topik | Keputusan |
|---|---|
| Mobile | Flutter, state **Riverpod**, `supabase-flutter`, routing `go_router` |
| Dashboard | React 19 + TypeScript + Vite |
| Backend | Supabase (Postgres, Auth, Storage, Edge Functions, Realtime, pg_cron) |
| Pembayaran | Midtrans (Snap + recurring + webhook) |
| Flavor mobile | 1 codebase, 2 entry point: `main_siswa.dart`, `main_tutor.dart`; pilih via `appFlavorProvider` |
| Uang | integer rupiah; `tutor_share = floor(harga×75/100)`; snapshot harga |
| Waktu | simpan UTC (`timestamptz`), tampil WIB |
| RLS | deny-by-default; helper `is_admin()`; service role hanya di Edge Function |
| Enum | pakai `text` + `check constraint` (bukan enum Postgres) agar mudah dimigrasi |
| Config klien | `--dart-define` (mobile) & `.env` (dashboard); anon/publishable key saja |

## Alasan

- Riverpod + go_router = ekosistem Flutter paling umum untuk app multi-peran.
- `check constraint` lebih ringan dimigrasi daripada `enum` (ALTER TYPE terbatas).
- Flavor lewat provider membuat widget bersama bisa tahu peran tanpa duplikasi kode.

## Langkah berikutnya

- Bila perlu pisah policy katalog tutor (kolom bank jangan ikut publik) → buat VIEW publik sebelum Fase 2. Sudah ditandai di `supabase/migrations/20261015000004_tutors.sql`.

## Tautan terkait

- [[2026-10-15-setup-fase-0-fondasi]]
- [[2026-10-15-konteks-proyek-kelasxtra-bimbel]]
