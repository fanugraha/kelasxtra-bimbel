# Fase 1 — Akun & Profil (Undangan Tutor)

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

Sesi 15 Okt 2026 (lanjutan). Menutup Fase 0 & mulai Fase 1. MCP supabase aktif,
dipakai untuk migrasi, deploy Edge Function, dan uji.

## Keputusan atau temuan

- **Tutup Fase 0**: akun admin pertama dibuat via SQL MCP (akun super admin,
  `role=admin`, `admin_role=NULL`). Uji login lolos. `flutter analyze` bersih.
- **Model admin**: super admin = `role='admin'` + `admin_role` NULL.
  `admin_role` hanya `verifikator|finance|konten|cs` (bukan `super_admin`).
- **Kredensial auth via SQL**: `auth.identities.email` *generated column*; butuh
  baris di `auth.users` **dan** `auth.identities` agar login jalan.
- **Fase 1 (backend)**:
  - Migrasi `...0007_audit_logs` (admin baca; insert hanya service role).
  - `invite-tutor` (admin): buat akun auth + `tutors` (diundang) + token 7 hari →
    balikan link aktivasi; kirim email bila `RESEND_API_KEY`+`EMAIL_FROM` ada.
  - `activate-tutor` (publik): validasi token → set password → isi profil/bank → aktif.
  - `manage-tutor` (admin): suspend (ban akun), reactivate (unban), resend undangan;
    semua tulis `audit_logs`.
- **Dashboard**: modul **Tutor & Undangan** (list/buat/kirim ulang/suspend) + halaman
  aktivasi web publik `/activate`.
- **Pivot penting — aktivasi lewat WEB, bukan deep link mobile**:
  custom scheme `kelasxtra://activate` tak andal — Flutter/go_router bisa salah
  memetakan host jadi path (rute jadi `/`, token hilang). Halaman web `/activate`
  di dashboard lebih sederhana: jalan di HP mana pun tanpa pasang app, tak perlu
  konfigurasi deep link. Versi layar mobile dihapus agar tak ada kode mati.
- **Default `ACTIVATION_BASE_URL`** di kode = `http://localhost:5173/activate` (dev).
  Produksi: set secret ke URL dashboard yang sebenarnya.
- **Uji end-to-end lolos** (Playwright + SQL): invite tutor → buka `/activate` →
  isi form → `tutors.status='aktif'` + data bank/pendidikan tersimpan; suspend →
  login diblokir ("User is banned") → reactivate → login jalan.

## Alasan

- Audit log ditulis di Edge Function (service role), bukan dari client, supaya jejak
  aksi tak bisa dipalsukan dan `audit_logs` tetap tanpa policy insert client.
- Email resmi dipisah: undangan pakai Resend API langsung dari Edge Function (kontrol
  penuh token & masa 7 hari); Supabase SMTP dipakai untuk email auth (konfirmasi siswa).

## Langkah berikutnya

- Set `RESEND_API_KEY`, `EMAIL_FROM`, `ACTIVATION_BASE_URL` (pemilik, manual di dashboard).
- Konfigurasi SMTP Resend di Supabase (Bagian B setup).
- Ganti password admin + rotate secret key lama.
- Sebelum Fase 2: buat VIEW katalog publik tutor tanpa kolom bank.

## Update (15 Okt 2026) — keputusan email + bersih-bersih

- **Keputusan: undangan lewat link manual**. Admin daftarkan tutor → salin link →
  kirim WhatsApp. Email otomatis **ditunda** sampai DNS domain beres.
- **Resend**: akun + API key dibuat, secret Supabase diset
  (`RESEND_API_KEY`, `EMAIL_FROM` = alamat pengirim di domain resmi, `ACTIVATION_BASE_URL`).
  Domain `kelasxtra.my.id` dikelola di **Cloudflare**; record Resend (DKIM `resend._domainkey`,
  CNAME `rsend`+`send` ke `*.forge.rmta.net`, DMARC `_dmarc`) **belum ditambahkan** →
  status belum Verified → kirim email ditolak (`domain is not verified`).
- **API key Resend terpapar**: key pernah ditempel ke chat (send-only). **Perlu di-rotate**
  di Resend sebelum dipakai produksi.
- **Bersih-bersih**: semua akun uji dihapus (tinggal akun admin pertama), `audit_logs`
  dikosongkan, image+volume Docker sisa deploy Edge Function dihapus, artefak Playwright
  dibuang + masuk `.gitignore`. `.env.example` sudah bersih (placeholder saja).
- **Catatan**: `.env` & `.env.example` tak bisa dibaca agent (aturan izin) — bersihkan manual bila perlu.

## Tautan terkait

- [[2026-10-15-setup-fase-0-fondasi]]
- [[2026-10-15-tooling-mcp-library]]
- [[2026-10-15-keputusan-teknis-kelasxtra]]

## Mobile Profil — selesai 17 Okt

`/profil` tidak lagi placeholder: `ProfilScreen` menampilkan nama/email, data siswa
(jenjang, sekolah, kontak darurat dari `students` via `fetchMyProfile()`), status langganan
bank soal, dan tombol keluar. Tutor memakai layar sama; kartu data siswa/langganan hanya
muncul untuk flavor siswa. Masih baca-saja (belum edit profil).
