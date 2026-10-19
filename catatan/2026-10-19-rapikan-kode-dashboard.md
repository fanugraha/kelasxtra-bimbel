# Rapikan kode dashboard (web)

## Konteks

Setelah merapikan struktur `apps/mobile`, giliran `apps/dashboard` (React + TS + Vite).
Analisa awal menemukan: 10 salinan `rupiah`, 8 salinan formatter tanggal, 3 salinan
`initials`, 2 salinan `invokeFn`, `MathText` (KaTeX) tersembunyi di dalam halaman,
dan 15 halaman yang memanggil `supabase.from(...)` langsung. Total ±6.300 baris.

## Keputusan atau temuan

- Utilitas murni dipindah ke `src/lib/`:
  - `format.ts` — `rupiah`, `rupiahCompact`, `formatDate`, `formatDateOnly`,
    `formatDateShort`, `formatDateTime`, `formatTime`, `isoDate` (semua zona WIB).
  - `text.ts` — `initials` (versi Layout yang juga menangani email/simbol).
  - `functions.ts` — `invokeFn` (panggil Edge Function + baca pesan galat).
- `MathText` (render rumus KaTeX) dipindah ke `components/MathText.tsx`; halaman
  `QuestionCms` tidak lagi mengimpor `react-katex`/CSS KaTeX.
- API mati dihapus: `looksLikeMathExpression` & `toTexExpression` tidak lagi diexport
  (hanya dipakai internal `mathText.ts`).
- **Tidak** dibuat lapisan repository/query bersama: 51 panggilan `supabase.from`
  memang query spesifik per modul, bukan duplikasi. Ini beda dari mobile yang punya
  repository tipis karena logika uang/booking dipakai ulang.
- **Tidak** dibuat komponen `Badge`: `badge`/`tone` sudah berupa kelas CSS di
  `index.css`, dan variasi pemakaiannya banyak (hitung, style, tone dinamis) sehingga
  pembungkusnya menambah prop tanpa manfaat.
- Peringatan `oxlint` tentang pemanggilan `Date` saat render adalah perilaku lama
  (jam berjalan di Layout/Overview/Tutors); sengaja tidak diubah di putaran ini.
- 5 halaman besar dipecah jadi folder `<Modul>/` berisi `index.tsx` + komponen
  bagian + `types.ts`; `pages/<Modul>.tsx` lama dihapus (`App.tsx` impor
  `'./pages/<Modul>'` otomatis menunjuk `index.tsx`):
  `GroupClasses` 573→255, `Monitoring` 555→248, `QuestionCms` 458→211,
  `Payroll` 440→286, `Moderation` 426→204 (baris `index.tsx`).
- Perbaikan yang ikut terbawa saat pecah: `canSubmit` di GroupProgramForm jadi
  `Boolean(...)` (dulu `string | boolean` → error TS2322); dialog konteks moderasi
  ditutup lewat `dialogRef.current?.close()` supaya event `close` native tetap
  memanggil `setDetail(null)` seperti sebelumnya (prop `onClose` hanya untuk event
  dialog, tombol "Tutup" memakai ref).

## Alasan

Dua duplikasi yang benar-benar identik disatukan; sisanya dibiarkan karena bukan
duplikasi (query per modul, meta status per domain). Aturan ini ditulis di
`docs/arsitektur.md` bagian "Struktur kode dashboard".

## Langkah berikutnya

- Verifikasi hanya statis (`npm run build` = `tsc -b` + vite, `npm run lint` = 6
  peringatan lama). Belum diuji klik di browser — perlu uji manual: booking group,
  koreksi absensi, CMS soal, payroll (buat/setujui/tandai/ekspor CSV), moderasi
  (buka konteks chat, peringatkan, tangguhkan).
- Halaman sisa >250 baris yang belum dipecah: Overview (380), Tutors (340),
  Vouchers (328), PackagePricing (317), Disputes (304), Packages (279) — tunggu
  kebutuhan, jangan pecah tanpa alasan.
