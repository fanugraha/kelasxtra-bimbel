-- Fase 2 — Tutup kolom sensitif `bookings` dari client.
-- Masalah: policy RLS menyembunyikan BARIS, bukan KOLOM. Siswa & tutor bisa `select`
-- barisnya sendiri lalu membaca `address` (sebelum bayar) dan `tutor_share`/
-- `platform_share` (bagi hasil internal).
-- Solusi: view `bookings_visible` (definer) tanpa kolom bagi hasil, `address` hanya
-- terbuka pasca-bayar, dan baris disaring lewat auth.uid(). Cabut akses tabel langsung.
--
-- Kenapa definer (bukan security_invoker): begitu SELECT pada tabel dicabut dari client,
-- invoker view ikut tak bisa membaca tabel dasar. Definisi definer + WHERE auth.uid()
-- memberi hasil sama (hanya baris milik sendiri) — pola sama seperti `tutor_catalog`.
-- Catatan: linter `security_definer_view` menandai ini; disengaja & dibatasi kolom aman.

create or replace view public.bookings_visible
as
select
  b.id, b.student_id, b.tutor_id, b.subject_id, b.jenjang, b.duration_minutes,
  b.mode, b.type, b.scheduled_at, b.price, b.discount, b.amount_due, b.status,
  b.voucher_id, b.created_at, b.updated_at,
  case
    when b.status in ('pending_payment', 'cancelled', 'expired') then null
    else b.address
  end as address
from public.bookings b
where b.student_id = auth.uid()
   or b.tutor_id = auth.uid()
   or public.is_admin();

revoke select on public.bookings from anon, authenticated;
grant select on public.bookings_visible to authenticated;
