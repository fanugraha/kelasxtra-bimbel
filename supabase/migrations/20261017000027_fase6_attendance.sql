-- Fase 6 — Absensi, reschedule, komplain, pesan, ulasan, ledger penghasilan.
-- Aturan inti (brief v2.0):
--   * check-in tutor ±15 menit; tanpa check-in s/d +15 menit → no_show_tutor
--   * offline: geofence 200 m bila titik lokasi tersedia (ruangan / booking)
--   * auto-complete H+1 setelah sesi berakhir bila tak ada komplain terbuka
--   * komplain s/d H+3, completed → disputed; earnings ditahan
--   * reschedule atomik, tanpa ganti mode, maks 14 hari, maks 2x per booking
--   * batal >24 jam: refund penuh / kuota kembali; <24 jam: 50% / kuota hangus
--   * thread pesan per booking, nomor telepon disaring, pesan ter-flag untuk admin
--   * tutor_earnings append-only: belum_dibayar → ditahan → sudah_dibayar

-- ============ Kolom baru ============
alter table public.bookings
  add column checkin_at        timestamptz,
  add column checkin_lat       double precision,
  add column checkin_lng       double precision,
  add column student_attended_at timestamptz,
  add column completed_at      timestamptz,
  add column cancelled_at      timestamptz,
  add column cancel_reason     text,
  add column refund_amount     integer not null default 0 check (refund_amount >= 0),
  add column reschedule_count  int not null default 0 check (reschedule_count >= 0),
  -- titik lokasi acuan geofence (diisi admin/ruangan; null = geofence tak dicek)
  add column location_lat      double precision,
  add column location_lng      double precision;

alter table public.rooms
  add column lat double precision,
  add column lng double precision;

create index bookings_completed_idx on public.bookings (completed_at);
create index bookings_checkin_idx   on public.bookings (checkin_at);

-- ============ Riwayat reschedule ============
create table public.booking_reschedules (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null references public.bookings (id) on delete cascade,
  from_at      timestamptz not null,
  to_at        timestamptz not null,
  requested_by uuid not null references public.profiles (id) on delete cascade,
  reason       text,
  created_at   timestamptz not null default now()
);

create index booking_reschedules_booking_idx on public.booking_reschedules (booking_id);

-- ============ Catatan sesi (wajib sebelum tutor menuntaskan sesi) ============
create table public.session_notes (
  booking_id uuid primary key references public.bookings (id) on delete cascade,
  tutor_id   uuid not null references public.tutors (id) on delete cascade,
  material   text not null,
  progress   text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger session_notes_set_updated_at
  before update on public.session_notes
  for each row execute function public.set_updated_at();

-- ============ Ulasan (1 per booking, maks H+3) ============
create table public.reviews (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  tutor_id   uuid not null references public.tutors (id) on delete cascade,
  rating     int not null check (rating between 1 and 5),
  comment    text,
  created_at timestamptz not null default now()
);

create index reviews_tutor_idx on public.reviews (tutor_id);

-- ============ Komplain ============
create table public.complaints (
  id             uuid primary key default gen_random_uuid(),
  booking_id     uuid not null references public.bookings (id) on delete cascade,
  opened_by      uuid not null references public.profiles (id) on delete cascade,
  category       text not null check (category in
                   ('tutor_absent', 'student_absent', 'quality', 'schedule', 'payment', 'other')),
  body           text not null,
  status         text not null default 'open'
                   check (status in ('open', 'in_review', 'resolved', 'rejected')),
  decision       text,
  refund_nominal int not null default 0 check (refund_nominal >= 0),
  resolved_by    uuid references public.profiles (id) on delete set null,
  resolved_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index complaints_booking_idx on public.complaints (booking_id);
create index complaints_status_idx  on public.complaints (status);

create trigger complaints_set_updated_at
  before update on public.complaints
  for each row execute function public.set_updated_at();

-- Maksimal satu komplain terbuka per booking.
create unique index complaints_open_unique
  on public.complaints (booking_id)
  where status in ('open', 'in_review');

-- ============ Ledger penghasilan tutor (append-only) ============
create table public.tutor_earnings (
  id              uuid primary key default gen_random_uuid(),
  booking_id      uuid not null unique references public.bookings (id) on delete restrict,
  tutor_id        uuid not null references public.tutors (id) on delete restrict,
  amount_tutor    integer not null check (amount_tutor >= 0),
  amount_platform integer not null check (amount_platform >= 0),
  status          text not null default 'belum_dibayar'
                    check (status in ('belum_dibayar', 'ditahan', 'sudah_dibayar')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index tutor_earnings_tutor_idx  on public.tutor_earnings (tutor_id);
create index tutor_earnings_status_idx on public.tutor_earnings (status);

create trigger tutor_earnings_set_updated_at
  before update on public.tutor_earnings
  for each row execute function public.set_updated_at();

-- ============ Thread pesan ============
create table public.booking_threads (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.thread_messages (
  id         uuid primary key default gen_random_uuid(),
  thread_id  uuid not null references public.booking_threads (id) on delete cascade,
  sender_id  uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (length(trim(body)) > 0),
  flagged    boolean not null default false,
  created_at timestamptz not null default now()
);

create index thread_messages_thread_idx on public.thread_messages (thread_id, created_at);

-- ============ Kehadiran kelas grup (per pertemuan per siswa) ============
create table public.group_attendance (
  group_session_id uuid not null references public.group_sessions (id) on delete cascade,
  student_id       uuid not null references public.students (id) on delete cascade,
  status           text not null check (status in ('hadir', 'izin', 'tidak_hadir')),
  recorded_by      uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  primary key (group_session_id, student_id)
);

create trigger group_attendance_set_updated_at
  before update on public.group_attendance
  for each row execute function public.set_updated_at();

-- ============ RLS ============
alter table public.booking_reschedules enable row level security;
alter table public.session_notes       enable row level security;
alter table public.reviews             enable row level security;
alter table public.complaints          enable row level security;
alter table public.tutor_earnings      enable row level security;
alter table public.booking_threads     enable row level security;
alter table public.thread_messages     enable row level security;
alter table public.group_attendance    enable row level security;

create policy "reschedules: peserta baca"
  on public.booking_reschedules for select
  using (exists (
    select 1 from public.bookings b
    where b.id = booking_id and (b.student_id = auth.uid() or b.tutor_id = auth.uid())
  ) or public.is_admin());

create policy "notes: tutor kelola"
  on public.session_notes for all
  using (tutor_id = auth.uid() or public.is_admin())
  with check (tutor_id = auth.uid() or public.is_admin());

create policy "notes: siswa baca"
  on public.session_notes for select
  using (exists (
    select 1 from public.bookings b
    where b.id = booking_id and b.student_id = auth.uid()
  ));

create policy "reviews: baca publik"
  on public.reviews for select using (true);

create policy "reviews: admin kelola"
  on public.reviews for all
  using (public.is_admin()) with check (public.is_admin());

create policy "complaints: peserta baca"
  on public.complaints for select
  using (opened_by = auth.uid() or exists (
    select 1 from public.bookings b
    where b.id = booking_id and (b.student_id = auth.uid() or b.tutor_id = auth.uid())
  ) or public.is_admin());

create policy "complaints: admin ubah"
  on public.complaints for update
  using (public.is_admin()) with check (public.is_admin());

create policy "earnings: tutor baca sendiri"
  on public.tutor_earnings for select
  using (tutor_id = auth.uid() or public.is_admin());

create policy "threads: peserta baca"
  on public.booking_threads for select
  using (exists (
    select 1 from public.bookings b
    where b.id = booking_id and (b.student_id = auth.uid() or b.tutor_id = auth.uid())
  ) or public.is_admin());

create policy "messages: peserta baca"
  on public.thread_messages for select
  using (exists (
    select 1
    from public.booking_threads t
    join public.bookings b on b.id = t.booking_id
    where t.id = thread_id and (b.student_id = auth.uid() or b.tutor_id = auth.uid())
  ) or public.is_admin());

create policy "attendance: tutor kelola"
  on public.group_attendance for all
  using (public.is_admin() or exists (
    select 1
    from public.group_sessions gs
    join public.group_classes gc on gc.id = gs.group_class_id
    where gs.id = group_session_id and gc.tutor_id = auth.uid()
  ))
  with check (public.is_admin() or exists (
    select 1
    from public.group_sessions gs
    join public.group_classes gc on gc.id = gs.group_class_id
    where gs.id = group_session_id and gc.tutor_id = auth.uid()
  ));

create policy "attendance: siswa baca sendiri"
  on public.group_attendance for select
  using (student_id = auth.uid() or public.is_admin());

-- ============ Helper ============
create or replace function public.booking_participant(p_booking uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.bookings b
    where b.id = p_booking
      and (b.student_id = auth.uid() or b.tutor_id = auth.uid())
  );
$$;

revoke all on function public.booking_participant(uuid) from public;
grant execute on function public.booking_participant(uuid) to authenticated;

-- Jarak meter (haversine).
create or replace function public.distance_meters(
  p_lat1 double precision, p_lng1 double precision,
  p_lat2 double precision, p_lng2 double precision
) returns double precision
language sql
immutable
as $$
  select 6371000 * 2 * asin(sqrt(
    power(sin(radians(p_lat2 - p_lat1) / 2), 2) +
    cos(radians(p_lat1)) * cos(radians(p_lat2)) *
    power(sin(radians(p_lng2 - p_lng1) / 2), 2)
  ));
$$;

-- ============ Absensi ============
create or replace function public.tutor_checkin(
  p_booking uuid,
  p_lat double precision default null,
  p_lng double precision default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
  v_ref_lat double precision;
  v_ref_lng double precision;
  v_dist double precision;
begin
  select * into v_b from public.bookings
   where id = p_booking and tutor_id = auth.uid() for update;

  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.status <> 'confirmed' then
    raise exception 'Sesi tidak bisa dimulai (status %)', v_b.status using errcode = '22023';
  end if;
  if v_b.checkin_at is not null then
    return jsonb_build_object('ok', true, 'checkin_at', v_b.checkin_at);
  end if;

  if now() < v_b.scheduled_at - interval '15 minutes' then
    raise exception 'Belum waktunya check-in (mulai 15 menit sebelum sesi)' using errcode = '22023';
  end if;
  if now() > v_b.scheduled_at + interval '15 minutes' then
    raise exception 'Batas check-in lewat; tandai siswa no-show lewat admin' using errcode = '22023';
  end if;

  if v_b.mode = 'offline' then
    if p_lat is null or p_lng is null then
      raise exception 'Lokasi wajib untuk sesi offline' using errcode = '22023';
    end if;
    -- Titik acuan: booking.location_*; fallback ruangan tak dipakai untuk privat.
    v_ref_lat := v_b.location_lat;
    v_ref_lng := v_b.location_lng;
    if v_ref_lat is not null and v_ref_lng is not null then
      v_dist := public.distance_meters(p_lat, p_lng, v_ref_lat, v_ref_lng);
      if v_dist > 200 then
        raise exception 'Di luar radius 200 m dari lokasi sesi (%.0f m)', round(v_dist) using errcode = '22023';
      end if;
    end if;
  end if;

  update public.bookings
     set status = 'in_progress',
         checkin_at = now(),
         checkin_lat = p_lat,
         checkin_lng = p_lng
   where id = v_b.id;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'booking.checkin', 'bookings', v_b.id::text,
          jsonb_build_object('lat', p_lat, 'lng', p_lng, 'distance_m', v_dist));

  return jsonb_build_object('ok', true, 'checkin_at', now(), 'distance_m', v_dist);
end;
$$;

grant execute on function public.tutor_checkin(uuid, double precision, double precision) to authenticated;

create or replace function public.student_attend(p_booking uuid)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_at timestamptz;
begin
  select student_attended_at into v_at from public.bookings
   where id = p_booking and student_id = auth.uid() for update;
  if not found then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_at is not null then
    return v_at;
  end if;
  update public.bookings
     set student_attended_at = now()
   where id = p_booking and status = 'in_progress';
  if not found then
    raise exception 'Sesi belum berjalan' using errcode = '22023';
  end if;
  return now();
end;
$$;

grant execute on function public.student_attend(uuid) to authenticated;

create or replace function public.mark_no_show(p_booking uuid, p_who text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
begin
  if p_who not in ('tutor', 'student') then
    raise exception 'p_who tidak valid' using errcode = '22023';
  end if;
  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.status not in ('confirmed', 'in_progress') then
    raise exception 'Status booking tidak bisa ditandai no-show' using errcode = '22023';
  end if;

  if p_who = 'student' then
    if v_b.tutor_id <> auth.uid() and not public.is_admin() then
      raise exception 'Hanya tutor/admin' using errcode = '42501';
    end if;
    if now() < v_b.scheduled_at then
      raise exception 'Sesi belum dimulai' using errcode = '22023';
    end if;
    update public.bookings set status = 'no_show_student' where id = p_booking;
  else
    if v_b.student_id <> auth.uid() and not public.is_admin() then
      raise exception 'Hanya siswa/admin' using errcode = '42501';
    end if;
    if now() < v_b.scheduled_at + interval '15 minutes' then
      raise exception 'Tunggu 15 menit setelah jadwal' using errcode = '22023';
    end if;
    update public.bookings set status = 'no_show_tutor' where id = p_booking;
  end if;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'booking.no_show', 'bookings', p_booking::text,
          jsonb_build_object('who', p_who, 'before_status', v_b.status));
end;
$$;

grant execute on function public.mark_no_show(uuid, text) to authenticated;

-- ============ Catatan sesi + tuntaskan ============
create or replace function public.save_session_note(
  p_booking uuid,
  p_material text,
  p_progress text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tutor uuid;
begin
  select id into v_tutor from public.tutors where id = auth.uid();
  if v_tutor is null then
    raise exception 'Hanya tutor' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.bookings where id = p_booking and tutor_id = v_tutor
  ) then
    raise exception 'Booking bukan milik tutor ini' using errcode = '42501';
  end if;
  if p_material is null or length(trim(p_material)) = 0 then
    raise exception 'Materi wajib diisi' using errcode = '22023';
  end if;

  insert into public.session_notes (booking_id, tutor_id, material, progress)
  values (p_booking, v_tutor, p_material, p_progress)
  on conflict (booking_id) do update
    set material = excluded.material,
        progress = excluded.progress;
end;
$$;

grant execute on function public.save_session_note(uuid, text, text) to authenticated;

-- Ledger append-only: satu baris per booking, dibuat sekali.
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
    (booking_id, tutor_id, amount_tutor, amount_platform)
  values (v_b.id, v_b.tutor_id, v_b.tutor_share, v_b.platform_share)
  on conflict (booking_id) do nothing;
end;
$$;

revoke all on function public.ensure_earning(uuid) from public;

create or replace function public.complete_booking(p_booking uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
begin
  select * into v_b from public.bookings
   where id = p_booking and tutor_id = auth.uid() for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.status = 'completed' then
    return;
  end if;
  if v_b.status <> 'in_progress' then
    raise exception 'Sesi belum berjalan' using errcode = '22023';
  end if;
  if not exists (select 1 from public.session_notes where booking_id = p_booking) then
    raise exception 'Isi catatan sesi sebelum menuntaskan' using errcode = '22023';
  end if;

  update public.bookings
     set status = 'completed', completed_at = now()
   where id = p_booking;

  perform public.ensure_earning(p_booking);

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'booking.complete', 'bookings', p_booking::text, jsonb_build_object('via', 'tutor'));
end;
$$;

grant execute on function public.complete_booking(uuid) to authenticated;

-- ============ Cron: no-show + auto-complete ============
create or replace function public.auto_complete_bookings()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_no_show int := 0;
  v_done int := 0;
  r record;
begin
  -- Tutor tak check-in s/d 15 menit setelah jadwal.
  with upd as (
    update public.bookings
       set status = 'no_show_tutor'
     where status = 'confirmed'
       and checkin_at is null
       and scheduled_at + interval '15 minutes' < now()
    returning id
  )
  select count(*) into v_no_show from upd;

  -- Sesi berjalan tanpa komplain terbuka sampai H+1 → completed.
  for r in
    select b.id
    from public.bookings b
    where b.status = 'in_progress'
      and b.scheduled_at + make_interval(mins => b.duration_minutes) + interval '1 day' < now()
      and not exists (
        select 1 from public.complaints c
        where c.booking_id = b.id and c.status in ('open', 'in_review')
      )
  loop
    update public.bookings set status = 'completed', completed_at = now() where id = r.id;
    perform public.ensure_earning(r.id);
    v_done := v_done + 1;
  end loop;

  return jsonb_build_object('no_show_tutor', v_no_show, 'completed', v_done);
end;
$$;

revoke all on function public.auto_complete_bookings() from public, anon, authenticated;

select cron.schedule(
  'auto-complete-bookings',
  '*/15 * * * *',
  $$select public.auto_complete_bookings();$$
);

-- ============ Reschedule (atomik) ============
create or replace function public.reschedule_booking(
  p_booking uuid,
  p_new_at timestamptz,
  p_reason text default null
) returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
  v_conflict int;
begin
  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.student_id <> auth.uid() and v_b.tutor_id <> auth.uid() then
    raise exception 'Bukan peserta booking' using errcode = '42501';
  end if;
  if v_b.status <> 'confirmed' then
    raise exception 'Hanya booking terkonfirmasi yang bisa direschedule' using errcode = '22023';
  end if;
  if v_b.reschedule_count >= 2 then
    raise exception 'Batas reschedule (2x) sudah tercapai' using errcode = '22023';
  end if;
  if p_new_at <= now() then
    raise exception 'Jadwal baru harus di masa depan' using errcode = '22023';
  end if;
  if p_new_at > now() + interval '14 days' then
    raise exception 'Reschedule maksimal 14 hari ke depan' using errcode = '22023';
  end if;

  if v_b.package_purchase_id is not null then
    if p_new_at > (select expires_at from public.package_purchases where id = v_b.package_purchase_id) then
      raise exception 'Jadwal baru melewati masa berlaku paket' using errcode = '22023';
    end if;
  end if;

  select count(*) into v_conflict
  from public.bookings b
  where b.id <> v_b.id
    and b.tutor_id = v_b.tutor_id
    and b.status in ('pending_payment', 'confirmed', 'in_progress')
    and b.scheduled_at < p_new_at + make_interval(mins => v_b.duration_minutes)
    and p_new_at < b.scheduled_at + make_interval(mins => b.duration_minutes);

  if v_conflict > 0 then
    raise exception 'Slot baru bentrok dengan sesi lain tutor' using errcode = '22023';
  end if;

  update public.bookings
     set scheduled_at = p_new_at,
         reschedule_count = reschedule_count + 1,
         lock_expires_at = null
   where id = v_b.id;

  insert into public.booking_reschedules (booking_id, from_at, to_at, requested_by, reason)
  values (v_b.id, v_b.scheduled_at, p_new_at, auth.uid(), p_reason);

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'booking.reschedule', 'bookings', v_b.id::text,
          jsonb_build_object('scheduled_at', v_b.scheduled_at),
          jsonb_build_object('scheduled_at', p_new_at, 'reason', p_reason));

  return p_new_at;
end;
$$;

grant execute on function public.reschedule_booking(uuid, timestamptz, text) to authenticated;

-- ============ Pembatalan (refund dicatat; dana manual oleh admin) ============
create or replace function public.cancel_booking(
  p_booking uuid,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
  v_hours numeric;
  v_refund int;
  v_restore_quota boolean := false;
begin
  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.student_id <> auth.uid() and not public.is_admin() then
    raise exception 'Hanya siswa/admin yang bisa membatalkan' using errcode = '42501';
  end if;
  if v_b.status <> 'confirmed' then
    raise exception 'Hanya booking terkonfirmasi yang bisa dibatalkan' using errcode = '22023';
  end if;

  v_hours := extract(epoch from (v_b.scheduled_at - now())) / 3600;

  if v_hours > 24 then
    v_refund := v_b.amount_due;
    v_restore_quota := v_b.package_purchase_id is not null;
  else
    v_refund := floor(v_b.amount_due * 50 / 100.0);
  end if;

  update public.bookings
     set status = 'cancelled',
         cancelled_at = now(),
         cancel_reason = p_reason,
         refund_amount = v_refund,
         lock_expires_at = null
   where id = v_b.id;

  if v_restore_quota then
    update public.package_purchases
       set sesi_terpakai = greatest(0, sesi_terpakai - 1)
     where id = v_b.package_purchase_id;
  end if;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'booking.cancel', 'bookings', v_b.id::text,
          jsonb_build_object('status', v_b.status),
          jsonb_build_object('refund_amount', v_refund, 'reason', p_reason,
                             'quota_restored', v_restore_quota));

  return jsonb_build_object('refund_amount', v_refund, 'quota_restored', v_restore_quota);
end;
$$;

grant execute on function public.cancel_booking(uuid, text) to authenticated;

-- ============ Komplain ============
create or replace function public.open_complaint(
  p_booking uuid,
  p_category text,
  p_body text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
  v_id uuid;
  v_base timestamptz;
begin
  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.student_id <> auth.uid() and v_b.tutor_id <> auth.uid() then
    raise exception 'Bukan peserta booking' using errcode = '42501';
  end if;
  if v_b.status not in ('completed', 'disputed') then
    raise exception 'Komplain hanya untuk sesi selesai' using errcode = '22023';
  end if;

  v_base := coalesce(v_b.completed_at, v_b.scheduled_at);
  if now() > v_base + interval '3 days' then
    raise exception 'Batas komplain H+3 sudah lewat' using errcode = '22023';
  end if;
  if p_body is null or length(trim(p_body)) = 0 then
    raise exception 'Isi komplain wajib' using errcode = '22023';
  end if;

  insert into public.complaints (booking_id, opened_by, category, body)
  values (v_b.id, auth.uid(), p_category, p_body)
  returning id into v_id;

  update public.bookings set status = 'disputed' where id = v_b.id;
  update public.tutor_earnings set status = 'ditahan'
   where booking_id = v_b.id and status = 'belum_dibayar';

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'complaint.open', 'complaints', v_id::text,
          jsonb_build_object('booking_id', v_b.id, 'category', p_category));

  return v_id;
end;
$$;

grant execute on function public.open_complaint(uuid, text, text) to authenticated;

create or replace function public.resolve_complaint(
  p_complaint uuid,
  p_status text,
  p_decision text,
  p_refund int default 0
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_c public.complaints;
  v_b public.bookings;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_status not in ('resolved', 'rejected') then
    raise exception 'Status keputusan tidak valid' using errcode = '22023';
  end if;
  if p_refund < 0 then
    raise exception 'Refund tidak boleh negatif' using errcode = '22023';
  end if;

  select * into v_c from public.complaints where id = p_complaint for update;
  if v_c.id is null then
    raise exception 'Komplain tidak ditemukan' using errcode = '22023';
  end if;
  if v_c.status in ('resolved', 'rejected') then
    return;
  end if;

  select * into v_b from public.bookings where id = v_c.booking_id for update;
  if p_refund > v_b.amount_due then
    raise exception 'Refund melebihi nilai transaksi' using errcode = '22023';
  end if;

  update public.complaints
     set status = p_status,
         decision = p_decision,
         refund_nominal = p_refund,
         resolved_by = auth.uid(),
         resolved_at = now()
   where id = p_complaint;

  if p_refund > 0 then
    update public.bookings
       set status = 'refunded',
           refund_amount = p_refund
     where id = v_b.id;
  else
    update public.bookings set status = 'completed' where id = v_b.id;
    update public.tutor_earnings set status = 'belum_dibayar'
     where booking_id = v_b.id and status = 'ditahan';
  end if;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'complaint.resolve', 'complaints', p_complaint::text,
          jsonb_build_object('status', p_status, 'refund', p_refund, 'booking_id', v_b.id));
end;
$$;

grant execute on function public.resolve_complaint(uuid, text, text, int) to authenticated;

-- ============ Ulasan ============
create or replace function public.submit_review(
  p_booking uuid,
  p_rating int,
  p_comment text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
  v_id uuid;
begin
  select * into v_b from public.bookings where id = p_booking;
  if v_b.id is null or v_b.student_id <> auth.uid() then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.status <> 'completed' then
    raise exception 'Ulasan hanya untuk sesi selesai' using errcode = '22023';
  end if;
  if p_rating not between 1 and 5 then
    raise exception 'Rating 1-5' using errcode = '22023';
  end if;
  if now() > coalesce(v_b.completed_at, v_b.scheduled_at) + interval '3 days' then
    raise exception 'Batas ulasan H+3 sudah lewat' using errcode = '22023';
  end if;
  if exists (select 1 from public.reviews where booking_id = p_booking) then
    raise exception 'Ulasan sudah dikirim' using errcode = '22023';
  end if;

  insert into public.reviews (booking_id, student_id, tutor_id, rating, comment)
  values (p_booking, auth.uid(), v_b.tutor_id, p_rating, p_comment)
  returning id into v_id;

  update public.tutors t
     set rating_avg = coalesce((
       select round(avg(r.rating)::numeric, 2) from public.reviews r where r.tutor_id = t.id
     ), 0)
   where t.id = v_b.tutor_id;

  return v_id;
end;
$$;

grant execute on function public.submit_review(uuid, int, text) to authenticated;

-- ============ Pesan ============
create or replace function public.ensure_booking_thread(p_booking uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.booking_threads (booking_id)
  values (p_booking)
  on conflict (booking_id) do nothing;

  select id into v_id from public.booking_threads where booking_id = p_booking;
  return v_id;
end;
$$;

revoke all on function public.ensure_booking_thread(uuid) from public;
grant execute on function public.ensure_booking_thread(uuid) to authenticated;

-- Thread otomatis saat booking terkonfirmasi.
create or replace function public.bookings_thread_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'confirmed' and (old.status is distinct from 'confirmed') then
    perform public.ensure_booking_thread(new.id);
  end if;
  return new;
end;
$$;

create trigger bookings_create_thread
  after insert or update of status on public.bookings
  for each row execute function public.bookings_thread_trigger();

-- Backfill booking yang sudah terkonfirmasi.
insert into public.booking_threads (booking_id)
select b.id from public.bookings b
where b.status in ('confirmed', 'in_progress', 'completed')
on conflict (booking_id) do nothing;

create or replace function public.send_booking_message(
  p_booking uuid,
  p_body text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_thread uuid;
  v_body text;
  v_flagged boolean := false;
  v_id uuid;
begin
  if not public.booking_participant(p_booking) then
    raise exception 'Bukan peserta booking' using errcode = '42501';
  end if;
  if p_body is null or length(trim(p_body)) = 0 then
    raise exception 'Pesan kosong' using errcode = '22023';
  end if;
  if length(p_body) > 2000 then
    raise exception 'Pesan maksimal 2000 karakter' using errcode = '22023';
  end if;

  v_body := p_body;
  if v_body ~ '(\+?62|0)8[0-9][0-9 -]{6,13}' then
    v_flagged := true;
    v_body := regexp_replace(
      v_body,
      '(\+?62|0)8[0-9][0-9 -]{6,13}',
      '[nomor disembunyikan]',
      'g'
    );
  end if;

  v_thread := public.ensure_booking_thread(p_booking);

  insert into public.thread_messages (thread_id, sender_id, body, flagged)
  values (v_thread, auth.uid(), v_body, v_flagged)
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.send_booking_message(uuid, text) to authenticated;

-- ============ Kehadiran kelas grup ============
create or replace function public.mark_group_attendance(
  p_session uuid,
  p_student uuid,
  p_status text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_status not in ('hadir', 'izin', 'tidak_hadir') then
    raise exception 'Status kehadiran tidak valid' using errcode = '22023';
  end if;
  if not (public.is_admin() or exists (
    select 1
    from public.group_sessions gs
    join public.group_classes gc on gc.id = gs.group_class_id
    where gs.id = p_session and gc.tutor_id = auth.uid()
  )) then
    raise exception 'Hanya tutor kelas/admin' using errcode = '42501';
  end if;

  insert into public.group_attendance
    (group_session_id, student_id, status, recorded_by)
  values (p_session, p_student, p_status, auth.uid())
  on conflict (group_session_id, student_id) do update
    set status = excluded.status,
        recorded_by = excluded.recorded_by;
end;
$$;

grant execute on function public.mark_group_attendance(uuid, uuid, text) to authenticated;

-- ============ View publik: tambah kolom absensi ============
create or replace view public.bookings_visible
as
select
  b.id, b.student_id, b.tutor_id, b.subject_id, b.jenjang, b.duration_minutes,
  b.mode, b.type, b.scheduled_at, b.price, b.discount, b.amount_due, b.status,
  b.voucher_id, b.created_at, b.updated_at,
  case
    when b.status in ('pending_payment', 'cancelled', 'expired') then null
    else b.address
  end as address,
  b.checkin_at,
  b.student_attended_at,
  b.completed_at,
  b.refund_amount,
  b.reschedule_count
from public.bookings b
where b.student_id = auth.uid()
   or b.tutor_id = auth.uid()
   or public.is_admin();

revoke select on public.bookings from anon, authenticated;
grant select on public.bookings_visible to authenticated;
