-- Fase 2 — Timeout booking: booking 'pending_payment' yang lock-nya lewat otomatis
-- menjadi 'expired' (dan payment 'pending' menjadi 'expire').
-- Dijadwalkan tiap 5 menit lewat pg_cron.

create or replace function public.expire_stale_bookings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
begin
  select array_agg(id) into v_ids
  from public.bookings
  where status = 'pending_payment'
    and lock_expires_at is not null
    and lock_expires_at < now();

  if v_ids is null then
    return 0;
  end if;

  update public.bookings
     set status = 'expired',
         lock_expires_at = null
   where id = any (v_ids);

  update public.payments
     set status = 'expire'
   where booking_id = any (v_ids)
     and status = 'pending';

  return array_length(v_ids, 1);
end;
$$;

-- Maintenance internal: jangan dipanggil client.
revoke all on function public.expire_stale_bookings() from public, anon, authenticated;

select cron.schedule(
  'expire-stale-bookings',
  '*/5 * * * *',
  $$select public.expire_stale_bookings();$$
);
