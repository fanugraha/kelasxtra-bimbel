-- Fase 4 — Kelas Grup (program, jadwal tetap)
-- Keputusan O1: min 3 kursi, tanpa subsidi, bayar sekali per kursi,
-- tenggat H-1 20:00 WIB; <3 → program batal (pindah kelas/kredit dulu, lalu refund penuh).

-- ============ Master ruangan ============
create table public.rooms (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  address    text,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.rooms enable row level security;
create policy "rooms: admin kelola"
  on public.rooms for all using (public.is_admin()) with check (public.is_admin());

-- ============ Program kelas grup ============
create table public.group_classes (
  id                   uuid primary key default gen_random_uuid(),
  tutor_id             uuid not null references public.tutors (id) on delete restrict,
  subject_id           uuid not null references public.subjects (id) on delete restrict,
  jenjang              text not null references public.levels (code),
  mode                 text not null check (mode in ('online', 'offline')),
  room_id              uuid references public.rooms (id) on delete set null,
  duration_minutes     int not null check (duration_minutes in (60, 90, 120)),
  total_sesi           int not null check (total_sesi in (4, 8, 12)),
  discount_percent     int not null default 0 check (discount_percent in (0, 5, 10)),
  price_per_session    int not null check (price_per_session >= 0),
  price_total          int not null check (price_total >= 0),
  min_seats            int not null default 3 check (min_seats between 1 and 5),
  max_seats            int not null default 5 check (max_seats between 1 and 5),
  seats_taken          int not null default 0 check (seats_taken >= 0),
  status               text not null default 'open'
                         check (status in ('open', 'confirmed', 'cancelled', 'completed')),
  min_confirm_deadline timestamptz not null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  check (seats_taken <= max_seats),
  check (min_seats <= max_seats)
);

create index group_classes_tutor_idx   on public.group_classes (tutor_id);
create index group_classes_status_idx  on public.group_classes (status);

create trigger group_classes_set_updated_at
  before update on public.group_classes
  for each row execute function public.set_updated_at();

-- ============ Pertemuan ============
create table public.group_sessions (
  id             uuid primary key default gen_random_uuid(),
  group_class_id uuid not null references public.group_classes (id) on delete cascade,
  seq            int not null,
  scheduled_at   timestamptz not null,
  created_at     timestamptz not null default now(),
  unique (group_class_id, seq)
);

create index group_sessions_class_idx on public.group_sessions (group_class_id);

-- ============ Kursi (1 siswa 1 kursi per program) ============
create table public.group_seats (
  id             uuid primary key default gen_random_uuid(),
  group_class_id uuid not null references public.group_classes (id) on delete cascade,
  student_id     uuid not null references public.students (id) on delete cascade,
  price_paid     int not null check (price_paid >= 0),
  status         text not null default 'pending_payment'
                   check (status in ('pending_payment', 'active', 'refund_pending', 'refunded', 'cancelled')),
  refund_amount  integer,
  lock_expires_at timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (group_class_id, student_id)
);

create index group_seats_class_idx   on public.group_seats (group_class_id);
create index group_seats_student_idx on public.group_seats (student_id);

create trigger group_seats_set_updated_at
  before update on public.group_seats
  for each row execute function public.set_updated_at();

alter table public.group_classes enable row level security;
alter table public.group_sessions enable row level security;
alter table public.group_seats enable row level security;

create policy "kelas grup: siswa baca kursinya"
  on public.group_seats for select using (student_id = auth.uid());
create policy "kelas grup: admin kelola"
  on public.group_seats for all
  using (public.is_admin()) with check (public.is_admin());
create policy "group_classes: admin kelola"
  on public.group_classes for all
  using (public.is_admin()) with check (public.is_admin());
create policy "group_sessions: admin kelola"
  on public.group_sessions for all
  using (public.is_admin()) with check (public.is_admin());

-- payments: tautkan ke kursi
alter table public.payments
  add column if not exists group_seat_id uuid
    references public.group_seats (id) on delete set null;
create index if not exists payments_group_seat_idx on public.payments (group_seat_id);

-- ============ View publik (aman) ============
create or replace view public.group_classes_visible as
select
  g.id, g.tutor_id, g.subject_id, g.jenjang, g.mode, g.duration_minutes,
  g.total_sesi, g.discount_percent, g.price_per_session, g.price_total,
  g.min_seats, g.max_seats, g.seats_taken, g.status, g.min_confirm_deadline,
  g.created_at, t.full_name as tutor_name, s.name as subject_name
from public.group_classes g
join public.tutors t on t.id = g.tutor_id
join public.subjects s on s.id = g.subject_id
where g.status in ('open', 'confirmed');

grant select on public.group_classes_visible to authenticated;

create or replace view public.group_sessions_visible as
select gs.id, gs.group_class_id, gs.seq, gs.scheduled_at
from public.group_sessions gs
join public.group_classes g on g.id = gs.group_class_id
where g.status in ('open', 'confirmed');

grant select on public.group_sessions_visible to authenticated;

-- ============ Helper ============
create or replace function public.group_discount(p_total_sesi int)
returns int language sql immutable as $$
  select case p_total_sesi when 4 then 0 when 8 then 5 when 12 then 10 else 0 end
$$;

-- ============ RPC: admin buat program ============
create or replace function public.admin_create_group_class(
  p_tutor uuid,
  p_subject uuid,
  p_jenjang text,
  p_mode text,
  p_room_id uuid,
  p_duration int,
  p_total_sesi int,
  p_days int[],
  p_start_date date,
  p_time time
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id      uuid;
  v_price   int;
  v_disc    int;
  v_total   int;
  v_days    int[];
  v_weeks   int;
  v_w       int;
  v_day     int;
  v_seq     int := 0;
  v_dt      date;
  v_ts      timestamptz;
  v_first   timestamptz;
  v_deadline timestamptz;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_total_sesi not in (4, 8, 12) then
    raise exception 'total_sesi harus 4, 8, atau 12' using errcode = '22023';
  end if;
  if p_days is null or array_length(p_days, 1) is null then
    raise exception 'Pilih minimal satu hari' using errcode = '22023';
  end if;

  select array_agg(d order by d) into v_days from unnest(p_days) as d;
  if exists (select 1 from unnest(v_days) as d where d < 1 or d > 7) then
    raise exception 'Hari tidak valid' using errcode = '22023';
  end if;
  if p_total_sesi % array_length(v_days, 1) <> 0 then
    raise exception 'Jumlah sesi harus kelipatan jumlah hari per minggu' using errcode = '22023';
  end if;
  v_weeks := p_total_sesi / array_length(v_days, 1);

  select price into v_price
  from public.price_matrix
  where jenjang = p_jenjang and duration_minutes = p_duration
    and mode = p_mode and type = 'grup' and active
  limit 1;
  if v_price is null then
    raise exception 'Harga grup belum diset untuk kombinasi ini' using errcode = '22023';
  end if;

  v_disc := public.group_discount(p_total_sesi);
  v_total := (v_price * p_total_sesi * (100 - v_disc)) / 100;

  -- Pertemuan pertama untuk menghitung tenggat.
  v_dt := p_start_date + ((v_days[1] - extract(isodow from p_start_date)::int + 7) % 7);
  v_first := (v_dt::timestamp + p_time) at time zone 'Asia/Jakarta';
  v_deadline := ((date_trunc('day', v_first at time zone 'Asia/Jakarta')
                  - interval '1 day' + interval '20 hours') at time zone 'Asia/Jakarta');

  insert into public.group_classes (
    tutor_id, subject_id, jenjang, mode, room_id, duration_minutes,
    total_sesi, discount_percent, price_per_session, price_total,
    min_seats, max_seats, status, min_confirm_deadline
  ) values (
    p_tutor, p_subject, p_jenjang, p_mode, p_room_id, p_duration,
    p_total_sesi, v_disc, v_price, v_total,
    3, 5, 'open', v_deadline
  ) returning id into v_id;

  for v_w in 0 .. v_weeks - 1 loop
    foreach v_day in array v_days loop
      v_dt := p_start_date
              + ((v_day - extract(isodow from p_start_date)::int + 7) % 7)
              + (v_w * 7);
      v_ts := (v_dt::timestamp + p_time) at time zone 'Asia/Jakarta';
      v_seq := v_seq + 1;
      insert into public.group_sessions (group_class_id, seq, scheduled_at)
      values (v_id, v_seq, v_ts);
    end loop;
  end loop;

  return v_id;
end;
$$;

revoke all on function public.admin_create_group_class(uuid, uuid, text, text, uuid, int, int, int[], date, time)
  from public, anon, authenticated;
grant execute on function public.admin_create_group_class(uuid, uuid, text, text, uuid, int, int, int[], date, time)
  to authenticated;

-- ============ RPC: kunci kursi (atomik) ============
create or replace function public.reserve_group_seat(
  p_group_class_id uuid,
  p_student uuid
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_price int;
  v_id uuid;
  v_updated int;
begin
  select price_total into v_price
  from public.group_classes
  where id = p_group_class_id and status = 'open' and seats_taken < max_seats
  for update;

  if v_price is null then
    raise exception 'Kursi tidak tersedia' using errcode = '22023';
  end if;

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
  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'Kursi tidak tersedia' using errcode = '22023';
  end if;

  insert into public.group_seats (group_class_id, student_id, price_paid, status, lock_expires_at)
  values (p_group_class_id, p_student, v_price, 'pending_payment',
          now() + interval '30 minutes')
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.reserve_group_seat(uuid, uuid) from public, anon, authenticated;
grant execute on function public.reserve_group_seat(uuid, uuid) to service_role;

-- ============ RPC: status kursi (settlement / gagal) ============
create or replace function public.activate_group_seat(p_seat_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.group_seats
     set status = 'active', lock_expires_at = null
   where id = p_seat_id and status = 'pending_payment';
$$;

create or replace function public.release_group_seat(p_seat_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_class uuid;
  v_status text;
begin
  select group_class_id, status into v_class, v_status
  from public.group_seats where id = p_seat_id;

  if v_status is null or v_status not in ('pending_payment', 'active') then
    return;
  end if;

  update public.group_seats set status = 'cancelled', lock_expires_at = null where id = p_seat_id;
  update public.group_classes
     set seats_taken = greatest(0, seats_taken - 1)
   where id = v_class;
end;
$$;

revoke all on function public.activate_group_seat(uuid) from public, anon, authenticated;
revoke all on function public.release_group_seat(uuid) from public, anon, authenticated;
grant execute on function public.activate_group_seat(uuid) to service_role;
grant execute on function public.release_group_seat(uuid) to service_role;

-- ============ Refund kursi (admin) ============
create or replace function public.refund_group_seat(p_seat_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.group_seats;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;

  select * into v from public.group_seats where id = p_seat_id for update;
  if v.id is null then
    raise exception 'Kursi tidak ditemukan' using errcode = '22023';
  end if;
  if v.status not in ('refund_pending', 'active') then
    raise exception 'Kursi tidak bisa direfund (status %)', v.status using errcode = '22023';
  end if;

  update public.group_seats
     set status = 'refunded', refund_amount = v.price_paid
   where id = p_seat_id;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'group_seat.refund', 'group_seats', p_seat_id::text,
          jsonb_build_object('status', v.status),
          jsonb_build_object('refund_amount', v.price_paid, 'status', 'refunded'));

  return v.price_paid;
end;
$$;

grant execute on function public.refund_group_seat(uuid) to authenticated;

-- ============ Cron: putuskan program + lepas kursi kedaluwarsa ============
create or replace function public.settle_group_classes()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  -- Jalan bila kuota minimum terpenuhi
  update public.group_classes
     set status = 'confirmed'
   where status = 'open'
     and min_confirm_deadline <= now()
     and seats_taken >= min_seats;
  get diagnostics v_count = row_count;

  -- Batal bila kurang; kursi aktif → menunggu refund
  update public.group_seats
     set status = 'refund_pending', refund_amount = price_paid
   where status = 'active'
     and group_class_id in (
       select id from public.group_classes
       where status = 'open' and min_confirm_deadline <= now() and seats_taken < min_seats
     );

  update public.group_classes
     set status = 'cancelled'
   where status = 'open'
     and min_confirm_deadline <= now()
     and seats_taken < min_seats;

  return v_count;
end;
$$;

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
    select id from public.group_seats
    where status = 'pending_payment'
      and lock_expires_at is not null and lock_expires_at < now()
  loop
    perform public.release_group_seat(r.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.settle_group_classes() from public, anon, authenticated;
revoke all on function public.expire_stale_group_seats() from public, anon, authenticated;

select cron.schedule('settle-group-classes', '*/5 * * * *', $$select public.settle_group_classes();$$);
select cron.schedule('expire-group-seats', '*/5 * * * *', $$select public.expire_stale_group_seats();$$);
