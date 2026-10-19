-- Beranda siswa — ringkasan tutor di view katalog
-- Tujuan: kartu tutor bisa menampilkan mapel, jenjang, hari tersedia, dan harga
-- "mulai dari" (sesi privat 60 menit) tanpa query tambahan dari aplikasi.
--
-- View tetap bypass RLS (security_invoker = false) dan tetap TANPA kolom sensitif
-- (bank, token undangan, alasan suspend). Harga di sini diambil dari `price_matrix`
-- dan memang informasi publik.
--
-- CREATE OR REPLACE hanya boleh MENAMBAH kolom di bagian akhir (urutan kolom lama
-- tidak boleh berubah), jadi kolom ringkasan ditaruh setelah `created_at`.

create or replace view public.tutor_catalog
with (security_invoker = false) as
select
  t.id,
  t.full_name,
  t.bio,
  t.education,
  t.photo_url,
  t.rating_avg,
  t.activated_at,
  t.created_at,
  -- Mapel yang diajar, dipisah koma dan diurut abjad (mis. "Fisika, Matematika").
  (
    select string_agg(distinct s.name, ', ' order by s.name)
    from public.tutor_subjects ts
    join public.subjects s on s.id = ts.subject_id
    where ts.tutor_id = t.id
  ) as subjects,
  -- Jenjang yang diajar, diurut SD → SMP → SMA (mis. "SMP, SMA").
  (
    select string_agg(j.jenjang, ', ' order by j.ord)
    from (
      select distinct
        ts.jenjang,
        case ts.jenjang
          when 'SD' then 1
          when 'SMP' then 2
          when 'SMA' then 3
          else 4
        end as ord
      from public.tutor_subjects ts
      where ts.tutor_id = t.id
    ) j
  ) as jenjang,
  -- Hari tersedia (0 = Minggu … 6 = Sabtu) dari slot ketersediaan yang aktif.
  coalesce(
    (
      select array_agg(distinct a.day_of_week order by a.day_of_week)
      from public.tutor_availability a
      where a.tutor_id = t.id
        and a.active
    ),
    '{}'::integer[]
  ) as days,
  -- Mode yang tersedia (online/offline) dari slot aktif.
  coalesce(
    (
      select array_agg(distinct a.mode order by a.mode)
      from public.tutor_availability a
      where a.tutor_id = t.id
        and a.active
    ),
    '{}'::text[]
  ) as modes,
  -- Harga privat 60 menit termurah untuk jenjang & mode tutor (dipakai kartu
  -- sebagai "mulai dari"). Bila tutor belum punya jadwal, mode apa pun dihitung.
  (
    select min(p.price)
    from public.price_matrix p
    where p.active
      and p.type = 'privat'
      and p.duration_minutes = 60
      and p.jenjang in (
        select ts.jenjang
        from public.tutor_subjects ts
        where ts.tutor_id = t.id
      )
      and (
        exists (
          select 1
          from public.tutor_availability a
          where a.tutor_id = t.id
            and a.active
            and a.mode = p.mode
        )
        or not exists (
          select 1
          from public.tutor_availability a
          where a.tutor_id = t.id
            and a.active
        )
      )
  ) as min_price
from public.tutors t
where t.status = 'aktif';

comment on view public.tutor_catalog is
  'Katalog publik tutor aktif (tanpa kolom bank/token) + ringkasan mapel/jenjang/hari/harga. Bypass RLS; jangan tambah kolom sensitif.';
