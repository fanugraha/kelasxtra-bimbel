-- Kursi kelas grup: tahan 5 menit, terisi hanya setelah lunas, aman dari balapan.
-- Diterapkan lewat `supabase db query --linked -f` (bukan `db push`, lihat
-- catatan jebakan migrasi), lalu dicatat di riwayat migrasi remote.
--
-- Model:
-- - `group_classes.seats_taken` = penghitung KAPASITAS (kursi lunas + tahanan
--   yang masih hidup). Diubah hanya di bawah kunci baris kelas (FOR UPDATE)
--   → dua siswa yang berebut kursi terakhir diproses berurutan, tidak bisa
--   oversell.
-- - Yang tampil ke siswa sebagai "terisi" = `seats_paid` (status active).
-- - Tahanan (`pending_payment`) hidup 5 menit; QRIS kursi grup juga 5 menit.
--
-- Perbaikan celah lama:
-- 1. Tahanan kedaluwarsa kini dibersihkan berdasarkan waktu (di dalam reserve
--    + cron tiap menit), tidak bergantung webhook Midtrans.
-- 2. Bayar terlambat (tahanan sudah dilepas) → activate mencoba ambil kursi
--    lagi; bila penuh/kelas tak lagi buka → RAISE agar payment ditandai untuk
--    refund admin (sebelumnya diam-diam 0 baris: uang masuk tanpa kursi).
-- 3. Tahanan kedaluwarsa milik siswa sendiri tak lagi memblokir "ambil lagi".
-- 4. Konfirmasi kuota minimum memakai kursi LUNAS, bukan termasuk tahanan.

-- ============ Helper: lepas tahanan kedaluwarsa satu kelas ============
-- Dipanggil dengan baris kelas SUDAH dikunci oleh pemanggil.
create or replace function public._release_expired_group_holds(p_class uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  with gone as (
    update public.group_seats
       set status = 'cancelled', lock_expires_at = null
     where group_class_id = p_class
       and status = 'pending_payment'
       and lock_expires_at is not null
       and lock_expires_at < now()
    returning 1
  )
  select count(*) into v_n from gone;

  if v_n > 0 then
    update public.group_classes
       set seats_taken = greatest(0, seats_taken - v_n)
     where id = p_class;
  end if;
  return v_n;
end;
$$;

revoke execute on function public._release_expired_group_holds(uuid) from public;
revoke execute on function public._release_expired_group_holds(uuid) from anon;
revoke execute on function public._release_expired_group_holds(uuid) from authenticated;

-- ============ Ambil kursi (tahan 5 menit) ============
create or replace function public.reserve_group_seat(p_group_class_id uuid, p_student uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cls public.group_classes;
  v_id uuid;
begin
  -- Kunci baris kelas: semua perubahan kapasitas kelas ini berurutan.
  select * into v_cls from public.group_classes
   where id = p_group_class_id for update;
  if v_cls.id is null or v_cls.status <> 'open' then
    raise exception 'Kelas ini sudah tidak menerima pendaftaran' using errcode = '22023';
  end if;

  -- Bersihkan tahanan yang sudah lewat 5 menit (termasuk milik siswa ini).
  perform public._release_expired_group_holds(p_group_class_id);

  if exists (
    select 1 from public.group_seats
     where group_class_id = p_group_class_id and student_id = p_student
       and status <> 'cancelled'
  ) then
    raise exception 'Kamu sudah punya kursi di kelas ini' using errcode = '22023';
  end if;

  update public.group_classes
     set seats_taken = seats_taken + 1
   where id = p_group_class_id and seats_taken < max_seats;
  if not found then
    raise exception 'Kursi sedang penuh. Coba lagi beberapa menit lagi' using errcode = '22023';
  end if;

  insert into public.group_seats (group_class_id, student_id, price_paid, status, lock_expires_at)
  values (p_group_class_id, p_student, v_cls.price_total, 'pending_payment',
          now() + interval '5 minutes')
  returning id into v_id;

  return v_id;
end;
$$;

-- ============ Lepas kursi (kunci kelas dulu) ============
create or replace function public.release_group_seat(p_seat_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_class uuid;
  v_status text;
begin
  select group_class_id into v_class from public.group_seats where id = p_seat_id;
  if v_class is null then return; end if;
  perform 1 from public.group_classes where id = v_class for update;

  select status into v_status from public.group_seats where id = p_seat_id for update;
  if v_status is null or v_status not in ('pending_payment', 'active') then
    return;
  end if;

  update public.group_seats set status = 'cancelled', lock_expires_at = null where id = p_seat_id;
  update public.group_classes
     set seats_taken = greatest(0, seats_taken - 1)
   where id = v_class;
end;
$$;

-- ============ Aktifkan kursi saat lunas ============
create or replace function public.activate_group_seat(p_seat_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seat public.group_seats;
  v_cls public.group_classes;
begin
  select * into v_seat from public.group_seats where id = p_seat_id;
  if v_seat.id is null then
    raise exception 'Kursi % tidak ditemukan', p_seat_id;
  end if;
  select * into v_cls from public.group_classes where id = v_seat.group_class_id for update;
  select * into v_seat from public.group_seats where id = p_seat_id for update;

  if v_seat.status = 'active' then
    return; -- idempoten (webhook ganda)
  end if;

  if v_seat.status = 'pending_payment' then
    -- Masih terhitung di seats_taken (tahanan belum dilepas) → cukup aktifkan,
    -- walau 5 menitnya baru saja lewat.
    update public.group_seats set status = 'active', lock_expires_at = null
     where id = p_seat_id;
    return;
  end if;

  -- Tahanan sudah dilepas lalu siswa tetap membayar: ambil kursi lagi bila ada.
  if v_seat.status = 'cancelled'
     and v_cls.status in ('open', 'confirmed')
     and v_cls.seats_taken < v_cls.max_seats
     and not exists (
       select 1 from public.group_seats
        where group_class_id = v_seat.group_class_id
          and student_id = v_seat.student_id
          and status <> 'cancelled' and id <> p_seat_id
     ) then
    update public.group_classes set seats_taken = seats_taken + 1 where id = v_cls.id;
    update public.group_seats set status = 'active', lock_expires_at = null
     where id = p_seat_id;
    return;
  end if;

  -- Tidak bisa diberi kursi → biarkan pemanggil menandai payment untuk refund.
  raise exception 'Kursi % tidak bisa diaktifkan (status %, kelas %, %/% kursi) — perlu refund',
    p_seat_id, v_seat.status, v_cls.status, v_cls.seats_taken, v_cls.max_seats;
end;
$$;

-- ============ Cron: lepas tahanan kedaluwarsa ============
create or replace function public.expire_stale_group_seats()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_count int := 0;
begin
  -- Berdasarkan waktu (5 menit) — per kelas, di bawah kunci baris kelas.
  for r in
    select distinct group_class_id as id from public.group_seats
     where status = 'pending_payment'
       and lock_expires_at is not null and lock_expires_at < now()
  loop
    perform 1 from public.group_classes where id = r.id for update;
    v_count := v_count + public._release_expired_group_holds(r.id);
  end loop;

  -- Berdasarkan status pembayaran gagal/kedaluwarsa dari Midtrans.
  for r in
    select s.id from public.group_seats s
      join public.payments p on p.group_seat_id = s.id
     where s.status = 'pending_payment'
       and p.status in ('expire', 'deny', 'cancel')
  loop
    perform public.release_group_seat(r.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ============ Konfirmasi kuota minimum: hitung kursi LUNAS ============
create or replace function public.settle_group_classes()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  -- Tahanan yang masih tergantung di batas waktu tidak ikut dihitung.
  perform public.expire_stale_group_seats();

  update public.group_classes g
     set status = 'confirmed'
   where g.status = 'open'
     and g.min_confirm_deadline <= now()
     and (select count(*) from public.group_seats s
           where s.group_class_id = g.id and s.status = 'active') >= g.min_seats;
  get diagnostics v_count = row_count;

  update public.group_seats
     set status = 'refund_pending', refund_amount = price_paid
   where status = 'active'
     and group_class_id in (
       select g.id from public.group_classes g
        where g.status = 'open' and g.min_confirm_deadline <= now()
     );

  update public.group_classes
     set status = 'cancelled'
   where status = 'open'
     and min_confirm_deadline <= now();

  return v_count;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'reserve_group_seat(uuid, uuid)', 'release_group_seat(uuid)',
    'activate_group_seat(uuid)', 'expire_stale_group_seats()',
    'settle_group_classes()'
  ] loop
    execute format('revoke execute on function public.%s from public', f);
    execute format('revoke execute on function public.%s from anon', f);
    execute format('revoke execute on function public.%s from authenticated', f);
  end loop;
end $$;

-- Tiap menit agar kursi yang ditinggal cepat kembali tersedia.
select cron.schedule('expire-group-seats', '* * * * *', 'select public.expire_stale_group_seats();');

-- ============ View: kursi lunas/ditahan + perkenalan tutor ============
-- Kolom lama tetap di urutan yang sama; kolom baru ditambah di akhir.
create or replace view public.group_classes_visible as
 select g.id,
    g.tutor_id,
    g.subject_id,
    g.jenjang,
    g.mode,
    g.duration_minutes,
    g.total_sesi,
    g.discount_percent,
    g.price_per_session,
    g.price_total,
    g.min_seats,
    g.max_seats,
    g.seats_taken,
    g.status,
    g.min_confirm_deadline,
    g.created_at,
    t.full_name as tutor_name,
    s.name as subject_name,
    (select min(gs.scheduled_at) from group_sessions gs where gs.group_class_id = g.id) as first_session,
    (select max(gs.scheduled_at) from group_sessions gs where gs.group_class_id = g.id) as last_session,
    (select count(*)::int from group_seats x
      where x.group_class_id = g.id and x.status = 'active') as seats_paid,
    (select count(*)::int from group_seats x
      where x.group_class_id = g.id and x.status = 'pending_payment'
        and x.lock_expires_at > now()) as seats_held,
    t.photo_url as tutor_photo_url,
    t.education as tutor_education,
    t.rating_avg as tutor_rating,
    t.bio as tutor_bio
   from group_classes g
     join tutors t on t.id = g.tutor_id
     join subjects s on s.id = g.subject_id
  where g.status = any (array['open'::text, 'confirmed'::text]);
