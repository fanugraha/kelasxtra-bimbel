# Fase 3 — Paket Sesi (Kredit)

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

16 Okt 2026. Paket sesi: siswa bayar sekali untuk 4/8/12 sesi, lalu booking memakai kuota
(tanpa bayar per sesi).

## Keputusan atau temuan

- **Tabel `package_purchases`** (migrasi `...00016`): snapshot `price_per_session` (harga
  **normal**, dipakai bagi hasil tutor), `discount_percent`, `price_total`, `total_sesi`,
  `sesi_terpakai`, `status`, `purchased_at`, `expires_at` (90 hari), `lock_expires_at`.
  Terikat **tutor + mapel + jenjang + durasi + mode** (satu kombinasi), supaya booking bisa
  dicocokkan dan harganya jelas.
- **Diskon**: 4→0%, 8→5%, 12→10%. `price_total = floor(per_sesi × jumlah × (100−diskon)/100)`.
- **Booking pakai kuota**: `bookings.package_purchase_id` diisi; `price` = harga normal,
  `discount` = price (jadi `amount_due` = 0, bayar Rp0), status langsung `confirmed`, tanpa
  baris `payments`. Kuota dikonsumsi lewat RPC `consume_package_session` (**atomik**, guard
  `sesi_terpakai < total_sesi`, plus cek cocok/aktif/belum kedaluwarsa).
- **Webhook** cabang `payments.type='package'`: settlement → paket `active` + `expires_at`
  +90 hari; deny/cancel/expire → `cancelled`/`expired`; refund → `refunded`.
- **Refund proporsional** (RPC `refund_package`, admin): `floor(price_total × sisa/total)`,
  tulis `audit_logs`. UI dashboard menyusul.
- **Cron** `expire_stale_packages` tiap 15 menit (paket lewat masa berlaku → `expired`).
- **Util Snap bersama** `supabase/functions/_shared/midtrans.ts` (dipakai `create-snap` &
  `create-package-snap`) — CLI bundling ikut menyertakan file `_shared` ✅.
- **RLS**: paket dibaca siswa sendiri + admin. Tutor sengaja **tidak** diberi akses (agar
  harga bayar siswa tak bocor); tutor tahu sesi dari paket lewat booking.

## Alasan

- Terikat satu kombinasi (bukan hanya tutor) → pencocokan kuota & harga saat booking
  deterministik; menghindari ambigu saat tutor mengajar banyak mapel/jenjang.
- Pakai RPC untuk konsumsi kuota (bukan app) karena hanya DB bisa menjamin bebas balapan.

## Verifikasi (backend, API nyata)

- Beli 8 sesi SMA Matematika 60 online → **646.000** (85.000×8 −5%).
- Webhook settlement → paket `active`, `expires_at` +90 hari.
- Pakai kuota → booking `confirmed`, `amount_due` 0, `sesi_terpakai` 1→2.
- Kuota habis → ditolak (tanpa booking tertinggal); slot bentrok → ditolak.
- Refund proporsional (2 terpakai dari 8) → **484.500**.
- Fungsi & data uji dihapus setelahnya.

## Langkah berikutnya

- Dashboard: layar refund paket (RPC siap).
- Fase 4 (kelas grup) atau Fase 5 (bank soal); butuh O1 sebelum Fase 4.

## Tautan terkait

- [[2026-10-16-voucher-checkout]]
- [[2026-10-15-rencana-pengembangan]]
