-- Fase 2 — VIEW katalog publik tutor
-- Tujuan: buka data tutor aktif ke publik TANPA kolom sensitif (bank, token undangan,
-- alasan suspend). Ganti policy "tutors: baca tutor aktif" yang membuka seluruh kolom.
--
-- View dimiliki role pemilik tabel (postgres) → menembus RLS, jadi filter status di sini.
-- JANGAN tambah kolom sensitif ke view ini.

create view public.tutor_catalog
with (security_invoker = false) as
select
  t.id,
  t.full_name,
  t.bio,
  t.education,
  t.photo_url,
  t.rating_avg,
  t.activated_at,
  t.created_at
from public.tutors t
where t.status = 'aktif';

comment on view public.tutor_catalog is
  'Katalog publik tutor aktif (tanpa kolom bank/token). Bypass RLS; jangan tambah kolom sensitif.';

grant select on public.tutor_catalog to anon, authenticated;

-- Cabut policy lama yang mengekspos semua kolom ke publik.
-- Katalog sekarang lewat view; akses tabel langsung tetap: tutor (baris sendiri) + admin.
drop policy "tutors: baca tutor aktif" on public.tutors;
