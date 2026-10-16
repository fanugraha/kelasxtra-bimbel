-- Lanjutan voucher: lepas kunci per-redemption (dipakai saat booking gagal dibuat,
-- jadi redemption belum sempat ditautkan ke booking).

create or replace function public.release_voucher_redemption(p_redemption_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  select id, voucher_id into r
  from public.voucher_redemptions
  where id = p_redemption_id and status = 'locked';

  if r.id is null then
    return;
  end if;

  update public.voucher_redemptions set status = 'released' where id = r.id;
  update public.vouchers set used = greatest(0, used - 1) where id = r.voucher_id;
end;
$$;

revoke all on function public.release_voucher_redemption(uuid)
  from public, anon, authenticated;
grant execute on function public.release_voucher_redemption(uuid) to service_role;

-- release_voucher_for_booking kini mendelegasikan ke fungsi di atas.
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
    select id from public.voucher_redemptions
    where booking_id = p_booking_id and status = 'locked'
  loop
    perform public.release_voucher_redemption(r.id);
  end loop;
end;
$$;

revoke all on function public.release_voucher_for_booking(uuid)
  from public, anon, authenticated;
grant execute on function public.release_voucher_for_booking(uuid) to service_role;
