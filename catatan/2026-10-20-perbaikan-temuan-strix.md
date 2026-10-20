# Perbaikan temuan pentest Strix dan rotasi kredensial

## Konteks
Strix menjalankan white-box scan pada `apps/mobile` dan `supabase`. Dua temuan utama: eskalasi admin lewat metadata signup, dan tutor bisa mengubah status/rating/rekening sendiri. Audit manual juga menemukan RPC sensitif masih dapat dieksekusi `anon`. Setelah perbaikan, legacy API key dan JWT secret Supabase dirotasi. Progres UI dari sesi Claude dicatat terpisah di `2026-10-20-penyempurnaan-ui-mobile.md`.

## Keputusan atau temuan
- Signup publik selalu membuat profil `student`; `role`/`admin_role` dari metadata diabaikan.
- Profil dan tutor dilindungi trigger yang mengunci kolom milik admin saat user mengubah datanya sendiri.
- `invite-tutor` menaikkan profil ke `tutor` lewat service role setelah akun dibuat; `activate-tutor` juga memastikan role tutor.
- Grant `anon`/PUBLIC dicabut dari sembilan RPC sensitif.
- `applyPaymentOutcome` memakai update bersyarat agar satu event hanya diproses sekali; status lunas tidak bisa diturunkan event terlambat.
- Aktivasi langganan sekarang menyimpan `last_payment_id`, jadi retry pembayaran yang sama tidak memperpanjang dua kali.
- Webhook Midtrans membandingkan `gross_amount` dengan nominal tersimpan.
- Payload registrasi Flutter tidak lagi mengirim `role`.
- Aktivasi tutor memakai kode OTP 6 digit yang dikirim ke email undangan; tautan saja tidak cukup. OTP disimpan sebagai hash, berlaku 10 menit, maksimal 5 percobaan.

## Verifikasi
- Simulasi signup dengan metadata `role=admin` dalam transaksi rollback menghasilkan profil `student`.
- Simulasi tutor mengubah status/rating/rekening dalam transaksi rollback: nilai lama dipertahankan.
- `anon_security_definer_functions = 0`.
- `flutter analyze` bersih; 64 tes lulus. Dashboard `npm run lint` hanya 6 peringatan lama dan `npm run build` sukses.
- Dua belas Edge Function dideploy ulang dengan helper kunci baru; `activate-tutor`, login user, dan `create-snap` diuji setelah rotasi.
- `activate_subscription` diuji dua kali dengan pembayaran yang sama dalam transaksi rollback: panggilan kedua mengembalikan `false` dan tidak menambah periode.
- Kolom OTP tutor tidak bisa diubah lewat self-update.
- Strix re-test `mobile_4999` selesai: 0 temuan baru, tetapi laporan quick scan mencatat 4 celah cakupan (coverage agent kosong), jadi bukan jaminan "bersih total".
- Verifikasi manual ulang: `anon` tetap 0 fungsi sensitif, guard profil/tutor dan idempotensi langganan masih sesuai.
- Golden test jadwal dibuat deterministik dengan tanggal tetap agar tidak gagal setiap hari.
- Grant `authenticated` dicabut dari helper internal `voucher_validate`, `ensure_booking_thread`, dan `ensure_earning`; pemanggil internal tetap bisa karena berjalan sebagai owner/service role.
- Sisa risiko yang perlu diputuskan: `submit_attempt` belum menyimpan daftar soal per attempt, jadi user bisa mengirim ID soal lain dan melihat kunci jawabannya. Perbaikan memerlukan kolom/tabel daftar soal per attempt.

## Audit kebocoran secret (20 Okt)
- Pemindaian pola secret di file kode, file yang dilacak Git, histori commit, blob/commit tak terjangkau, dan artefak build: tidak ditemukan API key, private key, service-role JWT, atau kredensial hardcoded.
- File env lokal (`apps/dashboard/.env`, `apps/mobile/.dev.env`) ada di disk tetapi sudah di-ignore dan tidak pernah masuk Git. Jangan ikutkan file itu saat zip/share folder.
- `apps/dashboard/.env.example` hanya placeholder dan tidak berubah sejak commit awal.
- Mobile hanya memakai URL + anon/publishable key lewat `--dart-define`; service role hanya dipakai Edge Functions dari environment.
- Rotasi selesai 20 Okt 2026: legacy `anon` dan `service_role` dimatikan lewat Management API; legacy JWT signing key HS256 (`3f9a9b67-4a4e-429c-bccc-1d4e7995ed42`) dicabut. Edge Functions sekarang memakai `SUPABASE_SECRET_KEYS`/`SUPABASE_PUBLISHABLE_KEYS` dengan fallback lama di `_shared/keys.ts`.
- Verifikasi pasca-rotasi: legacy anon/service role ditolak `401 Legacy API keys are disabled`; `activate-tutor` tetap bisa query database; login user dengan publishable key dan `create-snap` berhasil melewati autentikasi. User uji sementara dihapus kembali.
- Client/build mobile dan dashboard harus memakai publishable key `sb_publishable_...`. Build lama yang masih membawa legacy anon key akan gagal dan perlu di-rebuild/di-update.
- `apps/mobile/.dev.env` sudah diarahkan ke publishable key. APK release siswa dan tutor dibangun ulang (masing-masing 63 MB), dipindai (publishable ada, legacy anon tidak ada), dan dipasang di HP `e68890180406`.

## Langkah berikutnya
- Audit akun admin selesai: satu akun admin dipertahankan, akun admin finance dihapus permanen (tidak punya data terkait).
- Aktifkan leaked-password protection di dashboard Supabase.
- Verifikasi rekening tutor secara manual sebelum payroll pertama.
- View `SECURITY DEFINER` dipertahankan karena memfilter `auth.uid()`; jangan diubah ke invoker tanpa menguji RLS tabel dasar.
