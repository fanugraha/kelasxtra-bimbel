-- Fase 14 — Ganti hari berpasangan & pembatalan khusus admin.
--
-- Keputusan pemilik:
--   * Siswa TIDAK bisa membatalkan sesi; harus komit ikut jadwal.
--     Bila berhalangan → ajukan GANTI HARI yang harus disetujui pihak lain.
--   * Tidak ada pengembalian uang tunai; jadwal hanya berpindah setelah
--     kedua pihak sepakat (atau admin).
--   * Pengajuan paling lambat 24 jam sebelum sesi; maksimal 14 hari ke depan;
--     harus di dalam jam ketersediaan tutor; tidak boleh bentrok.
--   * `cancel_booking` kini khusus admin (operasional) dengan refund 0.
--
-- Perubahan ini menggantikan `reschedule_booking` yang lama (sepihak). Fungsi
-- lama tetap ada sebagai alat admin, tetapi tidak lagi boleh dipanggil peserta.

-- ============ 1. Tabel pengajuan ganti hari ============
create table if not exists public.reschedule_requests (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references public.bookings (id) on delete cascade,
  requested_by  uuid not null references public.profiles (id) on delete cascade,
  from_at       timestamptz not null,
  to_at         timestamptz not null,
  reason        text not null,
  status        text not null default 'pending'
                  check (status in ('pending', 'accepted', 'rejected', 'expired', 'cancelled')),
  respond_by    timestamptz not null,
  responded_by  uuid references public.profiles (id) on delete set null,
  responded_at  timestamptz,
  response_note text,
  created_at    timestamptz not null default now()
);

create index if not exists reschedule_requests_booking_idx
  on public.reschedule_requests (booking_id, created_at desc);
create index if not exists reschedule_requests_status_idx
  on public.reschedule_requests (status, respond_by);

-- Hanya boleh ada satu pengajuan yang menunggu jawaban per sesi.
create unique index if not exists reschedule_requests_one_pending
  on public.reschedule_requests (booking_id)
  where status = 'pending';

alter table public.reschedule_requests enable row level security;

-- Peserta baca riwayat pengajuan sesinya; admin semuanya. Tulis lewat RPC saja.
drop policy if exists "ajuan ganti hari: peserta baca" on public.reschedule_requests;
create policy "ajuan ganti hari: peserta baca"
  on public.reschedule_requests for select
  using (
    requested_by = auth.uid()
    or exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.student_id = auth.uid() or b.tutor_id = auth.uid())
    )
    or public.is_admin()
  );

-- Teks bebas dari pengguna tetap disaring (tautan/nomor HP/email ditolak).
drop trigger if exists guard_reschedule_requests on public.reschedule_requests;
create trigger guard_reschedule_requests
  before insert or update of reason, response_note on public.reschedule_requests
  for each row execute function public.enforce_text_guard('reason', 'response_note');

-- ============ 2. Helper jam ketersediaan ============
-- Sesi harus muat di satu jendela ketersediaan tutor (hari + jam + mode).
create or replace function public.tutor_free_at(
  p_tutor uuid,
  p_at timestamptz,
  p_minutes integer,
  p_mode text
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.tutor_availability a
    where a.tutor_id = p_tutor
      and a.active
      and a.mode = p_mode
      and a.day_of_week = extract(dow from p_at at time zone 'Asia/Jakarta')::int
      and a.start_time <= (p_at at time zone 'Asia/Jakarta')::time
      and a.end_time >= (p_at at time zone 'Asia/Jakarta')::time
                            + make_interval(mins => p_minutes)
  );
$$;

revoke all on function public.tutor_free_at(uuid, timestamptz, integer, text) from public;
grant execute on function public.tutor_free_at(uuid, timestamptz, integer, text) to authenticated;

-- Jadwal kosong untuk tutor & siswa (dipakai saat mengajukan/menyetujui).
create or replace function public.slot_is_free(
  p_booking uuid,
  p_at timestamptz,
  p_duration integer,
  p_tutor uuid,
  p_student uuid
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.bookings b
    where b.id <> p_booking
      and b.status not in ('cancelled', 'expired', 'refunded')
      and b.scheduled_at < p_at + make_interval(mins => p_duration)
      and p_at < b.scheduled_at + make_interval(mins => b.duration_minutes)
      and (b.tutor_id = p_tutor or b.student_id = p_student)
  );
$$;

revoke all on function public.slot_is_free(uuid, timestamptz, integer, uuid, uuid) from public;
grant execute on function public.slot_is_free(uuid, timestamptz, integer, uuid, uuid) to authenticated;

-- ============ 3. Ajukan ganti hari ============
create or replace function public.request_reschedule(
  p_booking uuid,
  p_new_at timestamptz,
  p_reason text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
  v_id uuid;
  v_respond_by timestamptz;
  v_other uuid;
begin
  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.student_id <> auth.uid() and v_b.tutor_id <> auth.uid() then
    raise exception 'Bukan peserta booking' using errcode = '42501';
  end if;
  if v_b.status <> 'confirmed' then
    raise exception 'Hanya sesi terkonfirmasi yang bisa diajukan ganti hari' using errcode = '22023';
  end if;
  if v_b.scheduled_at - now() < interval '24 hours' then
    raise exception 'Ganti hari diajukan paling lambat 24 jam sebelum sesi' using errcode = '22023';
  end if;
  if p_reason is null or length(trim(p_reason)) < 5 then
    raise exception 'Tulis alasan ganti hari (minimal 5 huruf)' using errcode = '22023';
  end if;
  if p_new_at <= now() then
    raise exception 'Jadwal baru harus di masa depan' using errcode = '22023';
  end if;
  if p_new_at > now() + interval '14 days' then
    raise exception 'Jadwal baru maksimal 14 hari ke depan' using errcode = '22023';
  end if;

  if v_b.package_purchase_id is not null
     and p_new_at > (select expires_at from public.package_purchases
                      where id = v_b.package_purchase_id) then
    raise exception 'Jadwal baru melewati masa berlaku paket' using errcode = '22023';
  end if;

  if not public.tutor_free_at(v_b.tutor_id, p_new_at, v_b.duration_minutes, v_b.mode) then
    raise exception 'Jadwal baru di luar jam ketersediaan tutor' using errcode = '22023';
  end if;

  if not public.slot_is_free(v_b.id, p_new_at, v_b.duration_minutes,
                             v_b.tutor_id, v_b.student_id) then
    raise exception 'Jadwal baru sudah terisi' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.reschedule_requests
    where booking_id = v_b.id and status = 'pending'
  ) then
    raise exception 'Sudah ada pengajuan ganti hari yang menunggu jawaban' using errcode = '22023';
  end if;

  -- Dijawab paling lama 12 jam, dan wajib sebelum sesi (paling lambat H-2 jam).
  v_respond_by := least(now() + interval '12 hours', v_b.scheduled_at - interval '2 hours');
  if v_respond_by <= now() then
    raise exception 'Waktu terlalu mepet untuk ganti hari' using errcode = '22023';
  end if;

  insert into public.reschedule_requests
    (booking_id, requested_by, from_at, to_at, reason, respond_by)
  values (v_b.id, auth.uid(), v_b.scheduled_at, p_new_at, trim(p_reason), v_respond_by)
  returning id into v_id;

  v_other := case when v_b.student_id = auth.uid() then v_b.tutor_id else v_b.student_id end;
  perform public.queue_notification(
    v_other, 'reschedule', 'Pengajuan ganti hari',
    format('Sesi %s diajukan pindah ke %s. Menunggu jawabanmu.',
      to_char(v_b.scheduled_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI'),
      to_char(p_new_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI')),
    jsonb_build_object('booking_id', v_b.id, 'request_id', v_id));

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'booking.reschedule_request', 'reschedule_requests', v_id::text,
          jsonb_build_object('scheduled_at', v_b.scheduled_at),
          jsonb_build_object('to_at', p_new_at, 'reason', trim(p_reason),
                             'respond_by', v_respond_by));

  return v_id;
end;
$$;

grant execute on function public.request_reschedule(uuid, timestamptz, text) to authenticated;

-- ============ 4. Jawab pengajuan (tolak/terima) ============
create or replace function public.respond_reschedule(
  p_request uuid,
  p_accept boolean,
  p_note text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_r public.reschedule_requests;
  v_b public.bookings;
begin
  select * into v_r from public.reschedule_requests where id = p_request for update;
  if v_r.id is null then
    raise exception 'Pengajuan tidak ditemukan' using errcode = '22023';
  end if;

  select * into v_b from public.bookings where id = v_r.booking_id for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;

  -- Yang menjawab harus pihak lain (bukan pengaju), kecuali admin.
  if not public.is_admin()
     and auth.uid() <> (case when v_b.student_id = v_r.requested_by
                              then v_b.tutor_id else v_b.student_id end) then
    raise exception 'Hanya pihak lain atau admin yang bisa menjawab' using errcode = '42501';
  end if;

  if v_r.status <> 'pending' then
    raise exception 'Pengajuan sudah tidak aktif' using errcode = '22023';
  end if;
  if now() > v_r.respond_by then
    update public.reschedule_requests set status = 'expired' where id = v_r.id;
    raise exception 'Pengajuan sudah kedaluwarsa' using errcode = '22023';
  end if;
  if v_b.status <> 'confirmed' or v_b.scheduled_at <> v_r.from_at then
    raise exception 'Jadwal sesi sudah berubah; pengajuan tidak berlaku lagi' using errcode = '22023';
  end if;

  if p_accept then
    if not public.tutor_free_at(v_b.tutor_id, v_r.to_at, v_b.duration_minutes, v_b.mode) then
      raise exception 'Jadwal baru di luar jam ketersediaan tutor' using errcode = '22023';
    end if;
    if not public.slot_is_free(v_b.id, v_r.to_at, v_b.duration_minutes,
                               v_b.tutor_id, v_b.student_id) then
      raise exception 'Jadwal baru sudah terisi' using errcode = '22023';
    end if;

    update public.bookings
       set scheduled_at = v_r.to_at,
           reschedule_count = reschedule_count + 1,
           lock_expires_at = null
     where id = v_b.id;

    insert into public.booking_reschedules (booking_id, from_at, to_at, requested_by, reason)
    values (v_b.id, v_r.from_at, v_r.to_at, v_r.requested_by,
            coalesce(nullif(trim(coalesce(p_note, '')), ''), v_r.reason));

    update public.reschedule_requests
       set status = 'accepted',
           responded_by = auth.uid(),
           responded_at = now(),
           response_note = p_note
     where id = v_r.id;

    insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
    values (auth.uid(), 'booking.reschedule', 'bookings', v_b.id::text,
            jsonb_build_object('scheduled_at', v_r.from_at),
            jsonb_build_object('scheduled_at', v_r.to_at, 'request_id', v_r.id));
  else
    update public.reschedule_requests
       set status = 'rejected',
           responded_by = auth.uid(),
           responded_at = now(),
           response_note = p_note
     where id = v_r.id;

    insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
    values (auth.uid(), 'booking.reschedule_reject', 'reschedule_requests', v_r.id::text,
            jsonb_build_object('booking_id', v_b.id, 'note', p_note));
  end if;

  -- Kabari kedua pihak.
  perform public.queue_notification(
    v_b.student_id, 'reschedule',
    case when p_accept then 'Ganti hari disetujui' else 'Ganti hari ditolak' end,
    format('Sesi %s %s.', to_char(v_r.from_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI'),
      case when p_accept
           then 'pindah ke ' || to_char(v_r.to_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI')
           else 'tetap pada jadwal semula' end),
    jsonb_build_object('booking_id', v_b.id, 'request_id', v_r.id));
  perform public.queue_notification(
    v_b.tutor_id, 'reschedule',
    case when p_accept then 'Ganti hari disetujui' else 'Ganti hari ditolak' end,
    format('Sesi %s %s.', to_char(v_r.from_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI'),
      case when p_accept
           then 'pindah ke ' || to_char(v_r.to_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI')
           else 'tetap pada jadwal semula' end),
    jsonb_build_object('booking_id', v_b.id, 'request_id', v_r.id));
end;
$$;

grant execute on function public.respond_reschedule(uuid, boolean, text) to authenticated;

-- Pengaju boleh menarik pengajuannya selama belum dijawab.
create or replace function public.cancel_reschedule_request(p_request uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_r public.reschedule_requests;
begin
  select * into v_r from public.reschedule_requests where id = p_request for update;
  if v_r.id is null then
    raise exception 'Pengajuan tidak ditemukan' using errcode = '22023';
  end if;
  if v_r.requested_by <> auth.uid() and not public.is_admin() then
    raise exception 'Hanya pengaju yang bisa menarik pengajuan' using errcode = '42501';
  end if;
  if v_r.status <> 'pending' then
    return;
  end if;
  update public.reschedule_requests set status = 'cancelled' where id = v_r.id;
end;
$$;

grant execute on function public.cancel_reschedule_request(uuid) to authenticated;

-- ============ 5. Kadaluwarsa otomatis ============
create or replace function public.expire_reschedule_requests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_n int := 0;
begin
  for r in
    select id, booking_id, requested_by
    from public.reschedule_requests
    where status = 'pending' and now() > respond_by
  loop
    update public.reschedule_requests set status = 'expired' where id = r.id;
    perform public.queue_notification(
      r.requested_by, 'reschedule', 'Pengajuan ganti hari kedaluwarsa',
      'Pengajuan ganti hari tidak dijawab tepat waktu. Sesi tetap pada jadwal semula.',
      jsonb_build_object('booking_id', r.booking_id, 'request_id', r.id));
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

revoke all on function public.expire_reschedule_requests() from public, anon, authenticated;

select cron.schedule(
  'expire-reschedule-requests',
  '*/10 * * * *',
  $$select public.expire_reschedule_requests();$$
);

-- ============ 6. Reschedule lama = alat admin saja ============
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
begin
  if not public.is_admin() then
    raise exception 'Pemindahan jadwal langsung hanya oleh admin; peserta memakai pengajuan ganti hari'
      using errcode = '42501';
  end if;

  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.status not in ('confirmed', 'no_show_tutor') then
    raise exception 'Status sesi tidak bisa dipindah (status %)', v_b.status using errcode = '22023';
  end if;
  -- Sesi gagal karena tentor hanya diganti bila memakai kuota paket; sesi
  -- satuan sudah dikompensasi poin (jangan dua kali).
  if v_b.status = 'no_show_tutor' and v_b.package_purchase_id is null then
    raise exception 'Sesi satuan yang tidak dihadiri tentor sudah diberi poin; tidak dipindah'
      using errcode = '22023';
  end if;
  if p_new_at <= now() then
    raise exception 'Jadwal baru harus di masa depan' using errcode = '22023';
  end if;
  if p_new_at > now() + interval '14 days' then
    raise exception 'Pemindahan maksimal 14 hari ke depan' using errcode = '22023';
  end if;
  if v_b.package_purchase_id is not null
     and p_new_at > (select expires_at from public.package_purchases
                      where id = v_b.package_purchase_id) then
    raise exception 'Jadwal baru melewati masa berlaku paket' using errcode = '22023';
  end if;
  if not public.slot_is_free(v_b.id, p_new_at, v_b.duration_minutes,
                             v_b.tutor_id, v_b.student_id) then
    raise exception 'Slot baru bentrok dengan sesi lain' using errcode = '22023';
  end if;

  update public.bookings
     set scheduled_at = p_new_at,
         status = case when v_b.status = 'no_show_tutor' then 'confirmed' else status end,
         lock_expires_at = null
   where id = v_b.id;

  insert into public.booking_reschedules (booking_id, from_at, to_at, requested_by, reason)
  values (v_b.id, v_b.scheduled_at, p_new_at, auth.uid(), p_reason);

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'booking.reschedule_admin', 'bookings', v_b.id::text,
          jsonb_build_object('scheduled_at', v_b.scheduled_at),
          jsonb_build_object('scheduled_at', p_new_at, 'reason', p_reason));

  return p_new_at;
end;
$$;

grant execute on function public.reschedule_booking(uuid, timestamptz, text) to authenticated;

-- ============ 7. Pembatalan: khusus admin, tanpa refund ============
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
  v_restore_quota boolean := false;
begin
  if not public.is_admin() then
    raise exception 'Sesi tidak bisa dibatalkan; ajukan ganti hari bersama pihak lain'
      using errcode = '42501';
  end if;

  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.status not in ('confirmed', 'no_show_tutor') then
    raise exception 'Hanya sesi terkonfirmasi yang bisa dibatalkan' using errcode = '22023';
  end if;

  -- Kuota paket bukan uang: dikembalikan agar sesi tidak hangus.
  v_restore_quota := v_b.package_purchase_id is not null;

  update public.bookings
     set status = 'cancelled',
         cancelled_at = now(),
         cancel_reason = p_reason,
         refund_amount = 0,
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
          jsonb_build_object('refund_amount', 0, 'reason', p_reason,
                             'quota_restored', v_restore_quota));

  return jsonb_build_object('refund_amount', 0, 'quota_restored', v_restore_quota);
end;
$$;

grant execute on function public.cancel_booking(uuid, text) to authenticated;
