-- Fase 7 — Payroll bulanan.
-- Prinsip: transfer manual admin; sistem hanya menghitung, mengunci periode,
-- mencatat approval & bukti transfer. Ledger tetap append-only.
--
-- Penguatan desain (lihat catatan 2026-10-17-fase-7-payroll-desain):
--   * periode dikunci (payroll_periods), earning telat → periode berikutnya
--   * tutor_earnings.payout_id mencegah dobel bayar
--   * honor kelas grup masuk ledger (source = group)
--   * snapshot rekening + transfer_ref di payouts
--   * four-eyes: approver ≠ pembuat periode

-- ============ Kolom ledger ============
alter table public.tutor_earnings
  add column payout_id        uuid,
  add column session_at       timestamptz,
  add column source           text not null default 'booking'
                                check (source in ('booking', 'group')),
  add column group_session_id uuid references public.group_sessions (id) on delete cascade,
  add column paid_at          timestamptz,
  alter column booking_id drop not null;

update public.tutor_earnings e
   set session_at = b.scheduled_at
  from public.bookings b
 where b.id = e.booking_id and e.session_at is null;

alter table public.tutor_earnings alter column session_at set not null;

alter table public.tutor_earnings
  add constraint tutor_earnings_source_ref check (
    (source = 'booking' and booking_id is not null)
    or (source = 'group' and group_session_id is not null)
  );

create unique index tutor_earnings_group_unique
  on public.tutor_earnings (group_session_id)
  where group_session_id is not null;

create index tutor_earnings_payout_idx  on public.tutor_earnings (payout_id);
create index tutor_earnings_session_idx on public.tutor_earnings (session_at);

-- ============ Periode & payout ============
create table public.payroll_periods (
  id           uuid primary key default gen_random_uuid(),
  period_start date not null,
  period_end   date not null,
  status       text not null default 'draft'
                 check (status in ('draft', 'approved', 'paid')),
  created_by   uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  approved_by  uuid references public.profiles (id) on delete set null,
  approved_at  timestamptz,
  paid_by      uuid references public.profiles (id) on delete set null,
  paid_at      timestamptz,
  check (period_end >= period_start),
  unique (period_start, period_end)
);

alter table public.payroll_periods enable row level security;

create policy "payroll: admin kelola"
  on public.payroll_periods for all
  using (public.is_admin()) with check (public.is_admin());

create table public.payouts (
  id                  uuid primary key default gen_random_uuid(),
  period_id           uuid not null references public.payroll_periods (id) on delete cascade,
  tutor_id            uuid not null references public.tutors (id) on delete restrict,
  amount              integer not null check (amount >= 0),
  status              text not null default 'draft'
                        check (status in ('draft', 'approved', 'paid')),
  -- snapshot rekening saat rekap (data bank bisa berubah setelahnya)
  bank_name           text,
  bank_account_number text,
  bank_account_holder text,
  transfer_ref        text,
  created_at          timestamptz not null default now(),
  approved_at         timestamptz,
  paid_at             timestamptz,
  unique (period_id, tutor_id)
);

alter table public.payouts enable row level security;

create policy "payouts: admin kelola"
  on public.payouts for all
  using (public.is_admin()) with check (public.is_admin());

create policy "payouts: tutor baca sendiri"
  on public.payouts for select
  using (tutor_id = auth.uid());

create index payouts_period_idx on public.payouts (period_id);
create index payouts_tutor_idx  on public.payouts (tutor_id);

create policy "payroll: tutor baca periodenya"
  on public.payroll_periods for select
  using (exists (
    select 1 from public.payouts p
    where p.period_id = id and p.tutor_id = auth.uid()
  ));


alter table public.tutor_earnings
  add constraint tutor_earnings_payout_fk
  foreign key (payout_id) references public.payouts (id) on delete set null;

-- ============ Ledger booking: sertakan session_at ============
create or replace function public.ensure_earning(p_booking uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
begin
  select * into v_b from public.bookings where id = p_booking;
  if v_b.id is null or v_b.status <> 'completed' then
    return;
  end if;
  insert into public.tutor_earnings
    (booking_id, tutor_id, amount_tutor, amount_platform, session_at, source)
  values (v_b.id, v_b.tutor_id, v_b.tutor_share, v_b.platform_share,
          v_b.scheduled_at, 'booking')
  on conflict (booking_id) do nothing;
end;
$$;
revoke all on function public.ensure_earning(uuid) from public;

-- ============ Honor kelas grup ============
-- Satu earning per pertemuan; honor = 75% x (harga/kursi x kursi aktif).
-- Kursi no-show tetap dihitung (status 'active').
create or replace function public.ensure_group_earnings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_count int := 0;
  v_total int;
  v_tutor int;
begin
  for r in
    select gs.id, gs.scheduled_at, gc.tutor_id, gc.price_per_session,
           (select count(*) from public.group_seats s
             where s.group_class_id = gc.id and s.status = 'active') as seats
    from public.group_sessions gs
    join public.group_classes gc on gc.id = gs.group_class_id
    where gc.status = 'confirmed'
      and gs.scheduled_at + make_interval(mins => gc.duration_minutes) + interval '1 day' < now()
      and not exists (
        select 1 from public.tutor_earnings e where e.group_session_id = gs.id
      )
  loop
    if r.seats > 0 then
      v_total := r.price_per_session * r.seats;
      v_tutor := floor(v_total * 75 / 100.0);
      insert into public.tutor_earnings
        (group_session_id, tutor_id, amount_tutor, amount_platform,
         session_at, source)
      values (r.id, r.tutor_id, v_tutor, v_total - v_tutor, r.scheduled_at, 'group')
      on conflict do nothing;
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;
revoke all on function public.ensure_group_earnings() from public, anon, authenticated;

select cron.schedule(
  'ensure-group-earnings',
  '*/15 * * * *',
  $$select public.ensure_group_earnings();$$
);

-- ============ RPC payroll ============
create or replace function public.admin_generate_payroll(
  p_start date,
  p_end date
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period uuid;
  v_payouts int := 0;
  v_earnings int := 0;
  v_total int := 0;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_start is null or p_end is null or p_end < p_start then
    raise exception 'Rentang periode tidak valid' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.payroll_periods
    where period_start = p_start and period_end = p_end
  ) then
    raise exception 'Periode ini sudah dibuat' using errcode = '22023';
  end if;

  insert into public.payroll_periods (period_start, period_end, created_by)
  values (p_start, p_end, auth.uid())
  returning id into v_period;

  -- Payout per tutor dari earning yang belum masuk payout mana pun.
  insert into public.payouts
    (period_id, tutor_id, amount, bank_name, bank_account_number, bank_account_holder)
  select v_period, e.tutor_id, sum(e.amount_tutor),
         t.bank_name, t.bank_account_number, t.bank_account_holder
  from public.tutor_earnings e
  join public.tutors t on t.id = e.tutor_id
  where e.payout_id is null
    and e.status = 'belum_dibayar'
    and (e.session_at at time zone 'Asia/Jakarta')::date between p_start and p_end
  group by e.tutor_id, t.bank_name, t.bank_account_number, t.bank_account_holder;

  with updated as (
    update public.tutor_earnings e
       set payout_id = p.id
      from public.payouts p
     where p.period_id = v_period
       and e.payout_id is null
       and e.status = 'belum_dibayar'
       and e.tutor_id = p.tutor_id
       and (e.session_at at time zone 'Asia/Jakarta')::date between p_start and p_end
    returning e.id
  )
  select count(*) into v_earnings from updated;

  select count(*), coalesce(sum(amount), 0)
    into v_payouts, v_total
  from public.payouts where period_id = v_period;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'payroll.generate', 'payroll_periods', v_period::text,
          jsonb_build_object('start', p_start, 'end', p_end,
                             'payouts', v_payouts, 'earnings', v_earnings,
                             'total', v_total));

  return jsonb_build_object(
    'period_id', v_period,
    'payouts', v_payouts,
    'earnings', v_earnings,
    'total', v_total
  );
end;
$$;
grant execute on function public.admin_generate_payroll(date, date) to authenticated;

create or replace function public.admin_approve_payroll(p_period uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_p public.payroll_periods;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  select * into v_p from public.payroll_periods where id = p_period for update;
  if v_p.id is null then
    raise exception 'Periode tidak ditemukan' using errcode = '22023';
  end if;
  if v_p.status <> 'draft' then
    raise exception 'Periode bukan draft' using errcode = '22023';
  end if;
  if v_p.created_by = auth.uid() then
    raise exception 'Four-eyes: approver harus admin lain' using errcode = '42501';
  end if;

  update public.payroll_periods
     set status = 'approved', approved_by = auth.uid(), approved_at = now()
   where id = p_period;
  update public.payouts
     set status = 'approved', approved_at = now()
   where period_id = p_period;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'payroll.approve', 'payroll_periods', p_period::text,
          jsonb_build_object('created_by', v_p.created_by));
end;
$$;
grant execute on function public.admin_approve_payroll(uuid) to authenticated;

create or replace function public.admin_cancel_payroll(p_period uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_p public.payroll_periods;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  select * into v_p from public.payroll_periods where id = p_period for update;
  if v_p.id is null then
    raise exception 'Periode tidak ditemukan' using errcode = '22023';
  end if;
  if v_p.status <> 'draft' then
    raise exception 'Hanya periode draft bisa dibatalkan' using errcode = '22023';
  end if;

  update public.tutor_earnings set payout_id = null where payout_id in (
    select id from public.payouts where period_id = p_period
  );
  delete from public.payouts where period_id = p_period;
  delete from public.payroll_periods where id = p_period;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'payroll.cancel', 'payroll_periods', p_period::text, '{}'::jsonb);
end;
$$;
grant execute on function public.admin_cancel_payroll(uuid) to authenticated;

create or replace function public.admin_mark_payroll_paid(
  p_period uuid,
  p_transfer_ref text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_p public.payroll_periods;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_transfer_ref is null or length(trim(p_transfer_ref)) = 0 then
    raise exception 'Referensi transfer wajib diisi' using errcode = '22023';
  end if;
  select * into v_p from public.payroll_periods where id = p_period for update;
  if v_p.id is null then
    raise exception 'Periode tidak ditemukan' using errcode = '22023';
  end if;
  if v_p.status <> 'approved' then
    raise exception 'Periode belum di-approve' using errcode = '22023';
  end if;

  update public.payouts
     set status = 'paid', paid_at = now(), transfer_ref = p_transfer_ref
   where period_id = p_period;
  update public.tutor_earnings e
     set status = 'sudah_dibayar', paid_at = now()
   where e.payout_id in (select id from public.payouts where period_id = p_period);
  update public.payroll_periods
     set status = 'paid', paid_by = auth.uid(), paid_at = now()
   where id = p_period;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'payroll.paid', 'payroll_periods', p_period::text,
          jsonb_build_object('transfer_ref', p_transfer_ref));
end;
$$;
grant execute on function public.admin_mark_payroll_paid(uuid, text) to authenticated;
