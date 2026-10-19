# Arsitektur Teknis

Ringkasan arsitektur. Acuan lengkap: [brief-implementasi-v2.0.md](brief-implementasi-v2.0.md).

## Tech stack

| Komponen | Pilihan |
|---|---|
| Mobile (siswa & tutor) | Flutter, **Riverpod**, `supabase-flutter` |
| Dashboard admin | React + TypeScript + Vite |
| Backend | Supabase: PostgreSQL + Auth + Storage + Edge Functions + Realtime + pg_cron |
| Pembayaran | Midtrans: Snap (sekali bayar), recurring (langganan), webhook |
| Push | Firebase Cloud Messaging (FCM) |
| Peta/lokasi | Geolocator (Flutter) untuk geofence check-in |

## Batas kepercayaan (trust boundary)

- Client (mobile/dashboard) hanya pakai **anon/publishable key**. Dilindungi RLS.
- **Service role key** hanya di Edge Functions, tidak pernah di client.
- Webhook Midtrans diverifikasi signature SHA512 di server; idempoten by `order_id`.

## State machine booking (11 status)

```
pending_payment → confirmed → in_progress → completed
                        ↘ cancelled
pending_payment → expired          (slot lock 30 menit lewat)
confirmed/in_progress → no_show_tutor / no_show_student
completed → disputed               (buka komplain s/d H+3 via CS)
```

Aturan terkait:
- Slot tutor **auto-accept** (tanpa terima/tolak).
- Auto-complete: `in_progress` tanpa komplain s/d **H+1** → `completed` (pg_cron).
- Reschedule **atomik** (kunci slot baru + lepas slot lama 1 transaksi), tanpa ganti mode, maks 14 hari, tidak melewati expiry paket.

## Pembayaran & bagi hasil

- Uang selalu **integer rupiah**.
- `tutor_share = floor(harga × 75 / 100)`, `platform_share = harga − tutor_share`.
- Harga di-**snapshot** ke booking/paket saat transaksi; perubahan price matrix hanya untuk transaksi baru.
- **Ledger append-only** `tutor_earnings`; status: `belum_dibayar → ditahan → sudah_dibayar`. Tidak ada kolom saldo yang di-update.

## Payroll bulanan

- Periode dihitung dari **tanggal jadwal sesi** (bukan tanggal completed).
- Cut-off tgl **25**. Kalender: rekap 26 → approval 27 → transfer 28 → slip 29.
- Four-eyes approval, ekspor daftar transfer, tombol "tandai sudah ditransfer".

## Paket = kredit

- `sesi_terpakai` bertambah per booking; ≤ `total_sesi`; booking ≤ `expires_at`; kuota kedaluwarsa hangus.
- Masa berlaku **90 hari**; diskon 4/8/12 sesi = 0%/5%/10%; terikat **1 tutor**.

## Voucher

- 1 voucher per transaksi; validasi real-time saat checkout.
- Kuota dikunci saat pembayaran dimulai (race-safe), dilepas bila gagal.
- **Diskon 100% ditanggung platform**; tutor tetap 75% dari **harga normal**.
- Refund penuh mengembalikan kuota per-siswa.

## Flavor mobile

Satu codebase Flutter, dua entry point: `main_siswa.dart` & `main_tutor.dart`,
diplih lewat `appFlavorProvider`. Lihat `apps/mobile/lib/core/`.

## Struktur kode mobile

Feature-first + repository tipis. **Tanpa** lapisan domain/usecase/entity terpisah —
untuk proyek solo itu menambah kode tanpa manfaat; tambahkan hanya bila benar-benar perlu.

```
apps/mobile/lib/
  core/                    infrastruktur bersama (dipakai semua fitur)
    theme/                 warna, tipografi, spacing, ThemeData (light+dark)
    widgets/               komponen UI pakai-ulang lintas fitur
    app_shell.dart         kerangka bottom-nav (di dalam core)
    format.dart            pemformatan uang / tanggal / jam (satu sumber)
    dates.dart             perbandingan tanggal (mis. isSameDay)
    errors.dart            pembersih pesan galat server (cleanError)
    constants.dart         nilai tetap lintas fitur (jenjang, durasi)
    router.dart            rute + redirect auth + bottom-nav shell
    nav_destinations.dart  tab bottom-nav per flavor
    supabase_client.dart · env.dart · app_flavor.dart · providers.dart · bootstrap.dart
  features/<fitur>/        satu fitur = data + state + tampilan
    <x>_repository.dart    satu-satunya yang bicara ke Supabase / Edge Function
    <x>_providers.dart     state Riverpod
    <x>_screen.dart        layar
    widgets/               komponen lokal fitur (dipakai beberapa layar di fitur itu)
    <layar>/               (bila layar besar) pecahan satu layar:
      <layar>_screen.dart    kerangka layar (Scaffold + state)
      <layar>_controller.dart   logika murni bila ada (mis. langkah/wizard)
      steps/ · widgets/      potongan tampilan layar itu
```

Aturan yang dipakai:

- **Layar tidak memanggil Supabase langsung** — selalu lewat `*_repository.dart`.
- Widget dipakai **≥2 fitur** → pindah ke `core/widgets/`; hanya 1 fitur → taruh di
  `features/<fitur>/widgets/`; hanya 1 layar → boleh di `features/<fitur>/<layar>/widgets/`.
- **Jangan menaruh satu folder `widgets/` global untuk semua hal** — hanya komponen lintas fitur.
- Layar yang membengkak (> ~300 baris) dipecah: kerangka tetap di `<x>_screen.dart`,
  potongan tampilan jadi widget bernama di `widgets/` (tetap dalam fitur yang sama).
- Format uang/tanggal/jam **selalu** lewat `AppFormat`; jarak & sudut lewat `AppSpacing` / `AppRadius`.
- Keadaan async lewat `AsyncView` (memuat / gagal + "Coba lagi" / data) agar seragam.
- Galat inline lewat `AppErrorText`; tombol lewat `AppButton` (punya state loading).

## Struktur kode dashboard

Dashboard admin lebih sederhana: satu komponen per modul, tanpa lapisan data
terpisah. Yang dibagi hanya **utilitas murni** dan **komponen render bersama**.

```
apps/dashboard/src/
  lib/
    supabase.ts    klien Supabase + isSupabaseConfigured
    auth.tsx       AuthProvider (session)
    auth-context.ts  context + useAuth (dipisah agar fast-refresh aman)
    format.ts      uang & tanggal (rupiah, formatDate*, formatTime, isoDate) — satu sumber
    text.ts        initials()
    functions.ts   invokeFn() untuk Edge Function + pembacaan pesan galat
    mathText.ts    pengubah notasi matematika → potongan TeX
  components/
    Layout.tsx     kerangka nav (sidebar/topbar)
    MathText.tsx   render teks/rumus (KaTeX)
    ModulePlaceholder.tsx  cadangan bila modul belum punya layar
  modules/registry.ts  daftar modul (path, label, grup) — sumber navigasi
  pages/<Modul>.tsx    satu layar per modul (layar kecil/sederhana)
  pages/<Modul>/       layar besar yang dipecah (lihat aturan di bawah)
```

Aturan yang dipakai:

- Format uang **selalu** `rupiah` dari `lib/format.ts`; format tanggal memakai
  `formatDate` (timestamp), `formatDateOnly` (tanggal polos `YYYY-MM-DD`),
  `formatDateShort`, `formatDateTime`, `formatTime`. Semua berzona `Asia/Jakarta`.
- Panggilan Edge Function **selalu** lewat `invokeFn` (`lib/functions.ts`) agar
  pesan galat server seragam.
- Halaman boleh memanggil `supabase.from(...)` langsung — Query-nya spesifik per
  modul, jadi tidak dibungkus lapisan repository (bukan duplikasi).
- Label/tone status (`STATUS_META`) tetap di halamannya masing-masing: tiap modul
  punya daftar status sendiri; hanya `badge <tone>` (CSS di `index.css`) yang dipakai bareng.
- Layar yang membengkak (>±400 baris) dipecah jadi folder bernama sama dengan
  halamannya: `pages/<Modul>/index.tsx` (state + handler + penyusunan bagian) dan
  komponen bagian bergaya PascalCase (`<Modul>/FlagsTable.tsx`,
  `<Modul>/types.ts` untuk tipe + label). Impor `'./pages/<Modul>'` di `App.tsx`
  otomatis menunjuk `index.tsx`, jadi file lama `pages/<Modul>.tsx` **dihapus**
  setelah dipindah. Contoh: `GroupClasses/`, `Monitoring/`, `QuestionCms/`,
  `Payroll/`, `Moderation/`.


