-- Fase 9 — Notifikasi (antrean) + hardening dasar.
-- Push FCM dikirim oleh Edge Function `send-push` (butuh FIREBASE_SERVICE_ACCOUNT).
-- Selama belum diset, notifikasi tetap tersimpan di tabel `notifications`.

-- ============ Token perangkat ============
create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  token      text not null unique,
  platform   text not null default 'android' check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

create policy "tokens: milik sendiri"
  on public.device_tokens for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "tokens: admin baca"
  on public.device_tokens for select using (public.is_admin());

-- ============ Antrean notifikasi ============
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  type       text not null,
  title      text not null,
  body       text not null,
  data       jsonb not null default '{}'::jsonb,
  status     text not null default 'pending'
               check (status in ('pending', 'sent', 'failed')),
  error      text,
  read_at    timestamptz,
  created_at timestamptz not null default now(),
  sent_at    timestamptz
);

create index notifications_user_idx   on public.notifications (user_id, created_at desc);
create index notifications_status_idx on public.notifications (status);

alter table public.notifications enable row level security;

create policy "notifikasi: baca sendiri"
  on public.notifications for select using (user_id = auth.uid() or public.is_admin());

create policy "notifikasi: tandai baca sendiri"
  on public.notifications for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============ Helper ============
create or replace function public.queue_notification(
  p_user uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
) returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (user_id, type, title, body, data)
  values (p_user, p_type, p_title, p_body, coalesce(p_data, '{}'::jsonb));
$$;
revoke all on function public.queue_notification(uuid, text, text, text, jsonb)
  from public, anon, authenticated;

-- ============ Trigger peristiwa ============
create or replace function public.notify_booking_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_when text;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  v_when := to_char(new.scheduled_at at time zone 'Asia/Jakarta',
                    'DD Mon YYYY HH24:MI');

  if new.status = 'confirmed' then
    perform public.queue_notification(new.student_id, 'booking',
      'Pemesanan dikonfirmasi',
      format('Sesi %s sudah dikonfirmasi.', v_when),
      jsonb_build_object('booking_id', new.id));
    perform public.queue_notification(new.tutor_id, 'booking',
      'Sesi baru masuk',
      format('Ada sesi baru pada %s.', v_when),
      jsonb_build_object('booking_id', new.id));
  elsif new.status = 'in_progress' then
    perform public.queue_notification(new.student_id, 'session',
      'Sesi dimulai',
      'Tutor sudah memulai sesi. Jangan lupa tandai kehadiranmu.',
      jsonb_build_object('booking_id', new.id));
  elsif new.status = 'completed' then
    perform public.queue_notification(new.student_id, 'review',
      'Sesi selesai',
      'Beri ulasan untuk tutor (maks H+3).',
      jsonb_build_object('booking_id', new.id));
  elsif new.status in ('cancelled', 'refunded',
                       'no_show_tutor', 'no_show_student') then
    perform public.queue_notification(new.student_id, 'booking',
      'Status sesi berubah', format('Sesi %s kini berstatus %s.', v_when, new.status),
      jsonb_build_object('booking_id', new.id));
    perform public.queue_notification(new.tutor_id, 'booking',
      'Status sesi berubah', format('Sesi %s kini berstatus %s.', v_when, new.status),
      jsonb_build_object('booking_id', new.id));
  end if;

  return new;
end;
$$;

create trigger bookings_notify_status
  after update of status on public.bookings
  for each row execute function public.notify_booking_status();

create or replace function public.notify_reschedule()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
  v_to uuid;
begin
  select * into v_b from public.bookings where id = new.booking_id;
  v_to := case when new.requested_by = v_b.student_id
               then v_b.tutor_id else v_b.student_id end;

  perform public.queue_notification(v_to, 'reschedule',
    'Jadwal sesi diubah',
    format('Jadwal baru: %s.',
           to_char(new.to_at at time zone 'Asia/Jakarta', 'DD Mon YYYY HH24:MI')),
    jsonb_build_object('booking_id', new.booking_id));

  return new;
end;
$$;

create trigger booking_reschedules_notify
  after insert on public.booking_reschedules
  for each row execute function public.notify_reschedule();

create or replace function public.notify_complaint_resolved()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('resolved', 'rejected')
     and old.status is distinct from new.status then
    perform public.queue_notification(new.opened_by, 'complaint',
      'Komplain ditinjau',
      format('Komplain kamu %s. %s',
             case when new.status = 'resolved' then 'selesai' else 'ditolak' end,
             coalesce(new.decision, '')),
      jsonb_build_object('complaint_id', new.id));
  end if;
  return new;
end;
$$;

create trigger complaints_notify_resolved
  after update of status on public.complaints
  for each row execute function public.notify_complaint_resolved();

create or replace function public.notify_payroll_paid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if new.status = 'paid' and old.status is distinct from 'paid' then
    for r in
      select tutor_id, amount from public.payouts where period_id = new.id
    loop
      perform public.queue_notification(r.tutor_id, 'payroll',
        'Honor sudah ditransfer',
        format('Honor %s untuk periode %s–%s sudah dikirim.',
               to_char(r.amount, 'FM999G999G999'), new.period_start, new.period_end),
        jsonb_build_object('period_id', new.id));
    end loop;
  end if;
  return new;
end;
$$;

create trigger payroll_notify_paid
  after update of status on public.payroll_periods
  for each row execute function public.notify_payroll_paid();

create or replace function public.notify_subscription_active()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'active' and old.status is distinct from 'active' then
    perform public.queue_notification(new.student_id, 'subscription',
      'Langganan bank soal aktif',
      'Kamu bisa mulai latihan dan tryout sekarang.',
      jsonb_build_object('subscription_id', new.id));
  end if;
  return new;
end;
$$;

create trigger subscriptions_notify_active
  after update of status on public.subscriptions
  for each row execute function public.notify_subscription_active();

-- ============ Rate limit sederhana (per user/aksi) ============
create table public.rate_limits (
  key          text primary key,
  window_start timestamptz not null default now(),
  count        int not null default 0
);

alter table public.rate_limits enable row level security;
-- Tidak ada policy: hanya fungsi definer yang menyentuh tabel ini.

create or replace function public.check_rate_limit(
  p_key text,
  p_max int,
  p_window_seconds int
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  insert into public.rate_limits as r (key, window_start, count)
  values (p_key, now(), 1)
  on conflict (key) do update
    set count = case when r.window_start < now() - make_interval(secs => p_window_seconds)
                     then 1 else r.count + 1 end,
        window_start = case when r.window_start < now() - make_interval(secs => p_window_seconds)
                            then now() else r.window_start end
  returning count into v_count;

  return v_count <= p_max;
end;
$$;
revoke all on function public.check_rate_limit(text, int, int)
  from public, anon, authenticated;

-- Terapkan ke chat: maks 20 pesan/menit per user.
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
  if not public.check_rate_limit('msg:' || auth.uid()::text, 20, 60) then
    raise exception 'Terlalu banyak pesan. Coba lagi sebentar.' using errcode = '22023';
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

-- Bersihkan rate limit lama (cron harian).
create or replace function public.cleanup_rate_limits()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v int;
begin
  delete from public.rate_limits where window_start < now() - interval '1 day';
  get diagnostics v = row_count;
  return v;
end;
$$;
revoke all on function public.cleanup_rate_limits() from public, anon, authenticated;

select cron.schedule(
  'cleanup-rate-limits',
  '17 3 * * *',
  $$select public.cleanup_rate_limits();$$
);
