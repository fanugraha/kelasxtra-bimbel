-- 1) Undangan tutor: tautkan aktivasi ke kepemilikan email lewat kode OTP.
alter table public.tutors
  add column if not exists invite_otp_hash text,
  add column if not exists invite_otp_expires_at timestamptz,
  add column if not exists invite_otp_attempts integer not null default 0,
  add column if not exists invite_otp_sent_at timestamptz;

-- Kolom OTP tetap milik server; tutor tidak boleh mengubahnya sendiri.
create or replace function public.guard_tutor_self_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id and not public.is_admin() then
    new.status := old.status;
    new.rating_avg := old.rating_avg;
    new.bank_name := old.bank_name;
    new.bank_account_number := old.bank_account_number;
    new.bank_account_holder := old.bank_account_holder;
    new.invite_token := old.invite_token;
    new.invite_expires_at := old.invite_expires_at;
    new.invited_at := old.invited_at;
    new.activated_at := old.activated_at;
    new.suspended_at := old.suspended_at;
    new.suspend_reason := old.suspend_reason;
    new.invite_otp_hash := old.invite_otp_hash;
    new.invite_otp_expires_at := old.invite_otp_expires_at;
    new.invite_otp_attempts := old.invite_otp_attempts;
    new.invite_otp_sent_at := old.invite_otp_sent_at;
  end if;
  return new;
end;
$$;

-- 2) Aktivasi langganan hanya boleh memperpanjang sekali per pembayaran.
alter table public.subscriptions
  add column if not exists last_payment_id uuid
    references public.payments (id) on delete set null;

-- Backfill supaya pembayaran lama tidak bisa memperpanjang lagi saat retry.
update public.subscriptions s
set last_payment_id = p.id
from (
  select distinct on (subscription_id) subscription_id, id
  from public.payments
  where subscription_id is not null
    and status = 'settlement'
  order by subscription_id, paid_at desc nulls last, created_at desc
) p
where s.id = p.subscription_id
  and s.last_payment_id is null;

drop function if exists public.activate_subscription(uuid);

create or replace function public.activate_subscription(
  p_subscription_id uuid,
  p_payment_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if p_payment_id is null then
    raise exception 'payment wajib' using errcode = '22023';
  end if;

  update public.subscriptions s
     set status = 'active',
         started_at = coalesce(s.started_at, now()),
         current_period_end = greatest(coalesce(s.current_period_end, now()), now())
                              + make_interval(days => p.period_days),
         grace_until = greatest(coalesce(s.current_period_end, now()), now())
                       + make_interval(days => p.period_days + p.grace_days),
         last_payment_id = p_payment_id
    from public.subscription_plans p
   where s.id = p_subscription_id
     and s.plan_code = p.code
     and s.last_payment_id is distinct from p_payment_id;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

revoke all on function public.activate_subscription(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.activate_subscription(uuid, uuid)
  to service_role;
