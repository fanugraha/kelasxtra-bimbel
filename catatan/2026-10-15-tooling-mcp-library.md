# Tooling: MCP, Skill, Library

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

Menyiapkan perkakas proyek: MCP server, skill proyek, dan library per fase.

## Keputusan atau temuan

**MCP** (di `~/.config/opencode/opencode.jsonc`, berlaku global) — butuh **restart opencode**:

| MCP | Command | Rahasia (env) |
|---|---|---|
| supabase | `npx -y @supabase/mcp-server-supabase@latest` | `SUPABASE_ACCESS_TOKEN` |
| context7 | `npx -y @upstash/context7-mcp@latest` | — (opsional untuk rate limit) |
| playwright | `npx -y @playwright/mcp@latest` | — |
| github | `npx -y @modelcontextprotocol/server-github@latest` | `GITHUB_PERSONAL_ACCESS_TOKEN` |

Rahasia **tidak** ditulis di config; server membaca env yang di-export sebelum menjalankan opencode.

**Skill proyek**: `.opencode/skills/kelasxtra-bimbel/SKILL.md` — memuat aturan bisnis kritis
(17 poin), konvensi kode, sumber kebenaran, dan cara verifikasi. Otomatis terpicu saat
bekerja di repo ini.

**Library terpasang**:
- Mobile: `intl`, `geolocator`, `firebase_core`, `firebase_messaging`, `image_picker`
  (+ sebelumnya `flutter_riverpod`, `supabase_flutter`, `go_router`).
- Dashboard: `katex`, `react-katex` (+ `@types/react-katex`).

## Alasan

- Supabase MCP: jalankan migrasi/query/generate tipe langsung dari agent.
- Context7: cegah API Flutter/Supabase/React yang kedaluwarsa.
- Playwright: uji dashboard di Fase 8; GitHub: kelola repo.
- Library dipasang walau fasenya belum tiba karena diminta; belum diimpor di kode.
  `firebase_*` **belum bisa build Android** sampai `google-services.json` + konfigurasi
  Firebase ada (Fase 9). `geolocator` butuh izin lokasi (Fase 6).

## Langkah berikutnya

- `export SUPABASE_ACCESS_TOKEN=...` dan `export GITHUB_PERSONAL_ACCESS_TOKEN=...`, lalu restart opencode.
- Setup Firebase project + `google-services.json` sebelum Fase 9.
- Import `katex` saat CMS soal (Fase 5); `geolocator` saat absensi (Fase 6).

## Tautan terkait

- [[2026-10-15-keputusan-teknis-kelasxtra]]
- [[2026-10-15-setup-fase-0-fondasi]]
- [[2026-10-15-konteks-proyek-kelasxtra-bimbel]]
