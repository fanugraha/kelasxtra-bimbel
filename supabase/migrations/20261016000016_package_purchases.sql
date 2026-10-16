-- Fase 3 — Paket Sesi (kredit)
-- Paket: 4/8/12 sesi, diskon 0/5/10%, terikat 1 tutor + mapel/jenjang/durasi/mode,
-- masa berlaku 90 hari, kuota kedaluwarsa hangus.

create table public.package_purchases (
  id                  uuid primary key default gen_random_uuid(),
  student_id          uuid not null references public.students (id) on delete cascade,
  tutor_id            uuid not null references public.tutors (id) on delete restrict,
  subject_id          uuid not null references public.subjects (id) on delete restrict,
  jenjang             text not null references public.levels (code),
  duration_minutes    int not null check (duration_minutes in (60, 90, 120)),
  mode                text not null check (mode in ('online', 'offline')),
  total_sesi          int not null check (total_sesi in (4, 8, 12)),
  sesi_terpakai       int not null default 0 check (sesi_terpakai >= 0),
  -- snapshot harga NORMAL per sesi (dipakai bagi hasil tutor)
  price_per_session   int not null check (price_per_session >= 0),
  discount_percent    int not null default 0 check (discount_percent in (0, 5, 10)),
  price_total         int not null check (price_total >= 0),
  status              text not null default 'pending_payment'
                        check (status in ('pending_payment', 'active', 'expired', 'refunded', 'cancelled')),
  purchased_at        timestamptz,
  expires_at          timestamptz,
  lock_expires_at     timestamptz,
  refund_amount       integer,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (sesi_terpakai <= total_sesi)
);

create index package_purchases_student_idx on public.package_purchases (student_id);
create index package_purchases_tutor_idx   on public.package_purchases (tutor_id);
create index package_purchases_status_idx  on public.package_purchases (status);

create trigger package_purchases_set_updated_at
  before update on public.package_purchases
  for each row execute function public.set_updated_at();

alter table public.package_purchases enable row level security;

-- Siswa baca paketnya sendiri; admin kelola. Tutor tidak (agar harga bayar siswa tak bocor).
create policy "paket: siswa baca sendiri"
  on public.package_purchases for select using (student_id = auth.uid());
create policy "paket: admin kelola"
  on public.package_purchases for all
  using (public.is_admin()) with check (public.is_admin());

-- payments: tautkan ke paket
alter table public.payments
  add column if not exists package_purchase_id uuid
    references public.package_purchases (id) on delete set null;
create index if not exists payments_package_idx on public.payments (package_purchase_id);

-- bookings: FK paket (kolom sudah ada dari Fase 2)
alter table public.bookings
  add constraint bookings_package_fk
    foreign key (package_purchase_id) references public.package_purchases (id) on delete set null;

-- ============ RPC ============

-- Pakai satu kuota paket (atomik) + tautkan ke booking.
create or replace function public.consume_package_session(
  p_package_id uuid,
  p_student uuid,
  p_tutor uuid,
  p_subject uuid,
  p_jenjang text,
  p_duration int,
  p_mode text,
  p_booking_id uuid
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v package_purchases;
  v_updated integer;
begin
  select * into v from public.package_purchases where id = p_package_id for update;
  if v.id is null then
    raise exception 'Paket tidak ditemukan' using errcode = '22023';
  end if;
  if v.student_id <> p_student then
    raise exception 'Paket bukan milikmu' using errcode = '22023';
  end if;
  if v.status <> 'active' then
    raise exception 'Paket tidak aktif' using errcode = '22023';
  end if;
  if v.expires_at is not null and now() > v.expires_at then
    raise exception 'Paket sudah kedaluwarsa' using errcode = '22023';
  end if;
  if v.sesi_terpakai >= v.total_sesi then
    raise exception 'Kuota paket habis' using errcode = '22023';
  end if;
  if v.tutor_id <> p_tutor or v.subject_id <> p_subject or v.jenjang <> p_jenjang
     or v.duration_minutes <> p_duration or v.mode <> p_mode then
    raise exception 'Paket tidak cocok dengan sesi ini' using errcode = '22023';
  end if;

  update public.package_purchases
     set sesi_terpakai = sesi_terpakai + 1
   where id = p_package_id and sesi_terpakai < total_sesi;
  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'Kuota paket habis' using errcode = '22023';
  end if;

  update public.bookings set package_purchase_id = p_package_id where id = p_booking_id;

  select sesi_terpakai into v_updated from public.package_purchases where id = p_package_id;
  return v_updated;
end;
$$;

revoke all on function public.consume_package_session(uuid, uuid, uuid, uuid, text, int, text, uuid)
  from public, anon, authenticated;
grant execute on function public.consume_package_session(uuid, uuid, uuid, uuid, text, int, text, uuid)
  to service_role;

-- Refund proporsional (admin). Sisa kuota × harga per sesi efektif.
create or replace function public.refund_package(p_package_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.package_purchases;
  v_refund integer;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;

  select * into v from public.package_purchases where id = p_package_id for update;
  if v.id is null then
    raise exception 'Paket tidak ditemukan' using errcode = '22023';
  end if;
  if v.status not in ('active', 'expired') then
    raise exception 'Paket tidak bisa direfund (status %)', v.status using errcode = '22023';
  end if;

  v_refund := (v.price_total * (v.total_sesi - v.sesi_terpakai)) / v.total_sesi;

  update public.package_purchases
     set status = 'refunded', refund_amount = v_refund
   where id = p_package_id;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'package.refund', 'package_purchases', p_package_id::text,
          jsonb_build_object('status', v.status, 'sesi_terpakai', v.sesi_terpakai),
          jsonb_build_object('refund_amount', v_refund, 'status', 'refunded'));

  return v_refund;
end;
$$;

grant execute on function public.refund_package(uuid) to authenticated;

-- Tandai paket aktif yang sudah lewat masa berlaku.
create or replace function public.expire_stale_packages()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.package_purchases
     set status = 'expired'
   where status = 'active' and expires_at is not null and expires_at < now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.expire_stale_packages() from public, anon, authenticated;

select cron.schedule(
  'expire-stale-packages',
  '*/15 * * * *',
  $$select public.expire_stale_packages();$$
);
