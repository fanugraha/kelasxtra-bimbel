-- Aktivasi/perpanjang langganan setelah pembayaran berhasil.
-- Perpanjangan dihitung dari tanggal berakhir yang masih berlaku (atau sekarang, bila sudah lewat).

create or replace function public.activate_subscription(p_subscription_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.subscriptions s
     set status = 'active',
         started_at = coalesce(s.started_at, now()),
         current_period_end = greatest(coalesce(s.current_period_end, now()), now())
                              + make_interval(days => p.period_days),
         grace_until = greatest(coalesce(s.current_period_end, now()), now())
                       + make_interval(days => p.period_days + p.grace_days)
    from public.subscription_plans p
   where s.id = p_subscription_id and s.plan_code = p.code;
end;
$$;

revoke all on function public.activate_subscription(uuid) from public, anon, authenticated;
grant execute on function public.activate_subscription(uuid) to service_role;
