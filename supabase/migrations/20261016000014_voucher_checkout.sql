-- Fase 2 — Voucher di checkout.
-- Validasi + kunci kuota race-safe saat pembayaran dimulai, dilepas bila gagal.
--
-- Alur: client cek harga (`check_voucher`, tanpa kunci) untuk pratinjau, lalu
-- `create-snap` memanggil `reserve_voucher` (kunci kuota). Webhook melepas kunci
-- (gagal/kedaluwarsa) atau menandainya terpakai (settlement).

-- Tautkan redemption ke booking agar bisa dilepas saat gagal.
alter table public.voucher_redemptions
  add column if not exists booking_id uuid references public.bookings (id) on delete set null;

create index if not exists voucher_redemptions_booking_idx
  on public.voucher_redemptions (booking_id);

-- Validasi bersama: mengembalikan baris voucher atau raise (errcode 22023).
create or replace function public.voucher_validate(
  p_code text,
  p_student uuid,
  p_price integer
) returns public.vouchers
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.vouchers;
  v_count integer;
begin
  if p_code is null or length(trim(p_code)) = 0 then
    raise exception 'Kode voucher kosong' using errcode = '22023';
  end if;

  select * into v
  from public.vouchers
  where upper(code) = upper(trim(p_code))
  limit 1;

  if v.id is null then
    raise exception 'Kode voucher tidak ditemukan' using errcode = '22023';
  end if;
  if not v.active then
    raise exception 'Voucher tidak aktif' using errcode = '22023';
  end if;
  if v.starts_at is not null and now() < v.starts_at then
    raise exception 'Voucher belum berlaku' using errcode = '22023';
  end if;
  if v.expires_at is not null and now() > v.expires_at then
    raise exception 'Voucher sudah kedaluwarsa' using errcode = '22023';
  end if;
  if p_price < v.min_purchase then
    raise exception 'Belum memenuhi minimal belanja voucher' using errcode = '22023';
  end if;
  if v.quota is not null and v.used >= v.quota then
    raise exception 'Kuota voucher sudah habis' using errcode = '22023';
  end if;

  select count(*) into v_count
  from public.voucher_redemptions
  where voucher_id = v.id
    and student_id = p_student
    and status <> 'released';
  if v_count >= v.per_student_limit then
    raise exception 'Kamu sudah memakai voucher ini' using errcode = '22023';
  end if;

  return v;
end;
$$;

-- Pratinjau diskon untuk siswa yang sedang login (tanpa mengunci kuota).
create or replace function public.check_voucher(p_code text, p_price integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.vouchers;
begin
  v := public.voucher_validate(p_code, auth.uid(), p_price);
  return case
    when v.discount_type = 'percent' then least(p_price, (p_price * v.discount_value) / 100)
    else least(p_price, v.discount_value)
  end;
end;
$$;

grant execute on function public.check_voucher(text, integer) to authenticated;

-- Kunci kuota (atomik) + catat redemption. Hanya dipakai server (service role).
create or replace function public.reserve_voucher(
  p_code text,
  p_student uuid,
  p_price integer
) returns table (voucher_id uuid, discount integer, redemption_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.vouchers;
  v_discount integer;
  v_redemption uuid;
  v_updated integer;
begin
  v := public.voucher_validate(p_code, p_student, p_price);

  v_discount := case
    when v.discount_type = 'percent' then least(p_price, (p_price * v.discount_value) / 100)
    else least(p_price, v.discount_value)
  end;

  -- Kunci kuota: update bertombol guard -> aman dari balapan (oversell).
  update public.vouchers
     set used = used + 1
   where id = v.id
     and (quota is null or used < quota);
  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'Kuota voucher sudah habis' using errcode = '22023';
  end if;

  insert into public.voucher_redemptions (voucher_id, student_id, status)
  values (v.id, p_student, 'locked')
  returning id into v_redemption;

  return query select v.id, v_discount, v_redemption;
end;
$$;

revoke all on function public.reserve_voucher(text, uuid, integer)
  from public, anon, authenticated;
grant execute on function public.reserve_voucher(text, uuid, integer) to service_role;

-- Tautkan redemption ke booking setelah booking dibuat.
create or replace function public.attach_voucher_redemption(
  p_redemption_id uuid,
  p_booking_id uuid
) returns void
language sql
security definer
set search_path = public
as $$
  update public.voucher_redemptions
     set booking_id = p_booking_id
   where id = p_redemption_id;
$$;

revoke all on function public.attach_voucher_redemption(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.attach_voucher_redemption(uuid, uuid) to service_role;

-- Lepas kunci voucher (pembayaran gagal/kedaluwarsa/dibatalkan).
create or replace function public.release_voucher_for_booking(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in
    select id, voucher_id
    from public.voucher_redemptions
    where booking_id = p_booking_id and status = 'locked'
  loop
    update public.voucher_redemptions set status = 'released' where id = r.id;
    update public.vouchers set used = greatest(0, used - 1) where id = r.voucher_id;
  end loop;
end;
$$;

revoke all on function public.release_voucher_for_booking(uuid)
  from public, anon, authenticated;
grant execute on function public.release_voucher_for_booking(uuid) to service_role;

-- Tandai redemption terpakai (pembayaran berhasil).
create or replace function public.consume_voucher_for_booking(p_booking_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.voucher_redemptions
     set status = 'used'
   where booking_id = p_booking_id and status = 'locked';
$$;

revoke all on function public.consume_voucher_for_booking(uuid)
  from public, anon, authenticated;
grant execute on function public.consume_voucher_for_booking(uuid) to service_role;
