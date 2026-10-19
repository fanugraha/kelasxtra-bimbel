-- Fase 13 — Penjaga race slot & pelepasan tahanan berbasis keputusan Midtrans.
--
-- Celah yang ditutup:
-- 1. `bookings` tidak punya penjaga slot di DB: `create-snap` hanya memeriksa
--    booking milik siswa yang sama, `reserve_package_schedule` memeriksa di
--    aplikasi (advisory lock), bukan constraint. Dua siswa bisa menahan slot
--    tutor yang sama → ditambah exclusion constraint (butuh `btree_gist`).
-- 2. `expire_stale_bookings` & `expire_stale_group_seats` melepas tahanan hanya
--    berdasarkan `lock_expires_at`. Bila webhook `settlement` datang setelah itu
--    (cron berjalan lebih dulu), slot sudah diambil orang lain tapi pembayaran
--    tetap dikonfirmasi → sesi dobel / uang masuk tanpa sesi. Sekarang pelepasan
--    hanya boleh terjadi kalau payment sudah dipastikan mati oleh Midtrans
--    (status expire/deny/cancel). Penentu tunggal = webhook + Edge
--    `reconcile-payments` (menanyakan `GET /v2/{order_id}/status`).
-- 3. `payments.review_required`: penanda bila ada pembayaran yang tidak bisa
--    diselesaikan otomatis (mis. constraint menolak konfirmasi) — tidak boleh
--    ditelan diam-diam, admin menyelesaikan manual.

create extension if not exists btree_gist;

-- ============ 1. Slot tidak boleh dobel ============
-- `timestamptz + interval` bertanda STABLE (interval bisa berisi bulan/hari, jadi
-- bergantung zona waktu) sehingga tidak boleh dipakai di index expression.
-- Durasi sesi hanya menit → pakai aritmetika epoch yang deterministik.
create or replace function public.booking_slot_range(p_start timestamptz, p_minutes integer)
returns tstzrange
language sql
immutable
as $$
  select tstzrange(p_start, to_timestamp(extract(epoch from p_start) + p_minutes * 60), '[)');
$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'bookings_no_tutor_overlap') then
    alter table public.bookings
      add constraint bookings_no_tutor_overlap
      exclude using gist (
        tutor_id with =,
        public.booking_slot_range(scheduled_at, duration_minutes) with &&
      )
      where (status in ('pending_payment', 'confirmed', 'in_progress'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'bookings_no_student_overlap') then
    alter table public.bookings
      add constraint bookings_no_student_overlap
      exclude using gist (
        student_id with =,
        public.booking_slot_range(scheduled_at, duration_minutes) with &&
      )
      where (status in ('pending_payment', 'confirmed', 'in_progress'));
  end if;
end $$;

-- ============ 2. Penanda pembayaran yang butuh tindakan admin ============
alter table public.payments add column if not exists review_required boolean not null default false;
alter table public.payments add column if not exists review_note text;

-- ============ 3. Sapu tahanan: hanya lepas bila payment sudah mati ============
-- Fungsi ini kini hanya *perbaikan* (mis. webhook sempat gagal menulis booking),
-- bukan penentu kedaluwarsa. Booking yang lock-nya lewat TIDAK lagi dilepas:
-- slot ditahan sampai Midtrans memutuskan (expire/deny/cancel) lewat webhook
-- atau Edge `reconcile-payments`. Dengan begitu pembayaran tidak mungkin masuk
-- setelah slot dilepas.
create or replace function public.expire_stale_bookings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
begin
  select array_agg(b.id) into v_ids
  from public.bookings b
  join public.payments p on p.booking_id = b.id
  where b.status = 'pending_payment'
    and p.status in ('expire', 'deny', 'cancel');

  if v_ids is null then
    return 0;
  end if;

  update public.bookings
     set status = 'expired',
         lock_expires_at = null
   where id = any (v_ids);

  return array_length(v_ids, 1);
end;
$$;

revoke all on function public.expire_stale_bookings() from public, anon, authenticated;

-- Kursi grup: sama, lepas hanya bila pembayarannya sudah mati.
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
  for r in
    select s.id
    from public.group_seats s
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

revoke all on function public.expire_stale_group_seats() from public, anon, authenticated;

-- Tahanan paket: sama, lepas hanya bila pembayarannya sudah mati.
create or replace function public.cancel_dead_package_holds()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_count int := 0;
begin
  for r in
    select pp.id, case when p.status = 'expire' then 'expired' else 'cancelled' end as target
    from public.package_purchases pp
    join public.payments p on p.package_purchase_id = pp.id
    where pp.status = 'pending_payment'
      and p.status in ('expire', 'deny', 'cancel')
  loop
    perform public.cancel_package_reservation(r.id, r.target);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.cancel_dead_package_holds() from public, anon, authenticated;

select cron.schedule(
  'cancel-dead-package-holds',
  '*/5 * * * *',
  $$select public.cancel_dead_package_holds();$$
);
