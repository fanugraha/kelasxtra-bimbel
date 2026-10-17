-- Fase 8 — Operasional dashboard: koreksi absensi, migrasi paket, metrik.
-- Semua aksi sensitif menulis `audit_logs`.

-- ============ Koreksi absensi (admin) ============
create or replace function public.admin_correct_booking(
  p_booking uuid,
  p_status text,
  p_scheduled_at timestamptz,
  p_reason text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_status not in ('confirmed', 'in_progress', 'completed',
                      'no_show_tutor', 'no_show_student', 'cancelled', 'refunded') then
    raise exception 'Status koreksi tidak diizinkan' using errcode = '22023';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'Alasan koreksi wajib' using errcode = '22023';
  end if;

  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;

  -- Lindungi ledger: booking yang earning-nya sudah masuk payout tidak boleh dikoreksi.
  if exists (
    select 1 from public.tutor_earnings
    where booking_id = p_booking and (payout_id is not null or status = 'sudah_dibayar')
  ) then
    raise exception 'Earning sudah masuk payroll; koreksi ditolak' using errcode = '22023';
  end if;
  if p_status <> 'completed' and exists (
    select 1 from public.tutor_earnings where booking_id = p_booking
  ) then
    raise exception 'Booking sudah punya earning; koreksi hanya boleh ke completed' using errcode = '22023';
  end if;

  update public.bookings
     set status = p_status,
         scheduled_at = coalesce(p_scheduled_at, scheduled_at),
         completed_at = case when p_status = 'completed'
                             then coalesce(completed_at, now())
                             else completed_at end
   where id = p_booking;

  if p_status = 'completed' then
    perform public.ensure_earning(p_booking);
  end if;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'booking.correct', 'bookings', p_booking::text,
          jsonb_build_object('status', v_b.status, 'scheduled_at', v_b.scheduled_at),
          jsonb_build_object('status', p_status,
                             'scheduled_at', coalesce(p_scheduled_at, v_b.scheduled_at),
                             'reason', p_reason));
end;
$$;
grant execute on function public.admin_correct_booking(uuid, text, timestamptz, text) to authenticated;

-- ============ Migrasi paket antar-tutor (persetujuan siswa) ============
create or replace function public.admin_transfer_package(
  p_package uuid,
  p_new_tutor uuid,
  p_consent boolean,
  p_reason text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_p public.package_purchases;
  v_old uuid;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if not coalesce(p_consent, false) then
    raise exception 'Persetujuan siswa wajib dicatat' using errcode = '22023';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'Alasan wajib diisi' using errcode = '22023';
  end if;

  select * into v_p from public.package_purchases where id = p_package for update;
  if v_p.id is null then
    raise exception 'Paket tidak ditemukan' using errcode = '22023';
  end if;
  if v_p.status not in ('active', 'expired') then
    raise exception 'Paket tidak bisa dipindah (status %)', v_p.status using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.tutors where id = p_new_tutor and status = 'aktif'
  ) then
    raise exception 'Tutor tujuan tidak aktif' using errcode = '22023';
  end if;

  v_old := v_p.tutor_id;

  update public.package_purchases
     set tutor_id = p_new_tutor
   where id = p_package;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'package.transfer', 'package_purchases', p_package::text,
          jsonb_build_object('tutor_id', v_old),
          jsonb_build_object('tutor_id', p_new_tutor,
                             'student_consent', true, 'reason', p_reason));

  -- Booking lama tetap memakai tutor saat transaksi (snapshot); hanya booking baru
  -- yang memakai tutor tujuan.
end;
$$;
grant execute on function public.admin_transfer_package(uuid, uuid, boolean, text) to authenticated;

-- ============ Metrik operasional & keuangan ============
create or replace function public.admin_metrics(
  p_from date,
  p_to date
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'bookings', jsonb_build_object(
      'total', (select count(*) from public.bookings
                 where (scheduled_at at time zone 'Asia/Jakarta')::date between p_from and p_to),
      'completed', (select count(*) from public.bookings
                 where status = 'completed'
                   and (scheduled_at at time zone 'Asia/Jakarta')::date between p_from and p_to),
      'cancelled', (select count(*) from public.bookings
                 where status in ('cancelled', 'refunded')
                   and (scheduled_at at time zone 'Asia/Jakarta')::date between p_from and p_to),
      'no_show', (select count(*) from public.bookings
                 where status in ('no_show_tutor', 'no_show_student')
                   and (scheduled_at at time zone 'Asia/Jakarta')::date between p_from and p_to),
      'disputed', (select count(*) from public.bookings
                 where status = 'disputed'
                   and (scheduled_at at time zone 'Asia/Jakarta')::date between p_from and p_to),
      'today', (select count(*) from public.bookings
                 where (scheduled_at at time zone 'Asia/Jakarta')::date
                       = (now() at time zone 'Asia/Jakarta')::date)
    ),
    'revenue', jsonb_build_object(
      'gross', (select coalesce(sum(amount), 0) from public.payments
                 where status in ('settlement', 'capture')
                   and (coalesce(paid_at, created_at) at time zone 'Asia/Jakarta')::date
                       between p_from and p_to),
      'gateway_fee', (select coalesce(sum(gateway_fee), 0) from public.payments
                 where status in ('settlement', 'capture')
                   and (coalesce(paid_at, created_at) at time zone 'Asia/Jakarta')::date
                       between p_from and p_to),
      'refunds', (select coalesce(sum(refund_amount), 0) from public.bookings
                 where refund_amount > 0
                   and (coalesce(cancelled_at, completed_at, scheduled_at) at time zone 'Asia/Jakarta')::date
                       between p_from and p_to),
      'platform_share', (select coalesce(sum(amount_platform), 0) from public.tutor_earnings
                 where (session_at at time zone 'Asia/Jakarta')::date between p_from and p_to),
      'tutor_earnings', (select coalesce(sum(amount_tutor), 0) from public.tutor_earnings
                 where (session_at at time zone 'Asia/Jakarta')::date between p_from and p_to),
      'tutor_unpaid', (select coalesce(sum(amount_tutor), 0) from public.tutor_earnings
                 where status in ('belum_dibayar', 'ditahan')),
      'tutor_paid', (select coalesce(sum(amount_tutor), 0) from public.tutor_earnings
                 where status = 'sudah_dibayar')
    ),
    'users', jsonb_build_object(
      'students', (select count(*) from public.students),
      'subscriptions_active', (select count(*) from public.subscriptions
                 where status = 'active'),
      'tutors_active', (select count(*) from public.tutors where status = 'aktif')
    ),
    'ops', jsonb_build_object(
      'in_progress', (select count(*) from public.bookings where status = 'in_progress'),
      'complaints_open', (select count(*) from public.complaints
                 where status in ('open', 'in_review')),
      'pending_bookings', (select count(*) from public.bookings
                 where status = 'pending_payment'),
      'groups_open', (select count(*) from public.group_classes where status = 'open')
    ),
    'tutors', (
      select coalesce(jsonb_agg(to_jsonb(row)), '[]'::jsonb) from (
        select
          t.id,
          t.full_name,
          t.rating_avg,
          (select count(*) from public.bookings b
            where b.tutor_id = t.id and b.status = 'completed'
              and (b.scheduled_at at time zone 'Asia/Jakarta')::date between p_from and p_to) as completed,
          (select count(*) from public.bookings b
            where b.tutor_id = t.id and b.status in ('cancelled', 'refunded')
              and (b.scheduled_at at time zone 'Asia/Jakarta')::date between p_from and p_to) as cancelled,
          (select count(*) from public.bookings b
            where b.tutor_id = t.id and b.status in ('no_show_tutor', 'no_show_student')
              and (b.scheduled_at at time zone 'Asia/Jakarta')::date between p_from and p_to) as no_show,
          (select coalesce(sum(e.amount_tutor), 0) from public.tutor_earnings e
            where e.tutor_id = t.id and e.status in ('belum_dibayar', 'ditahan')) as unpaid
        from public.tutors t
        where t.status = 'aktif'
        order by t.full_name
      ) row
    ),
    'students', (
      select coalesce(jsonb_agg(to_jsonb(row)), '[]'::jsonb) from (
        select
          s.id,
          s.full_name,
          s.jenjang,
          (select count(*) from public.bookings b
            where b.student_id = s.id and b.status = 'completed'
              and (b.scheduled_at at time zone 'Asia/Jakarta')::date between p_from and p_to) as sessions,
          (select count(*) from public.attempts a
            where a.student_id = s.id
              and (a.started_at at time zone 'Asia/Jakarta')::date between p_from and p_to) as attempts
        from public.students s
        order by s.full_name
      ) row
    )
  ) into v_result;

  return v_result;
end;
$$;
grant execute on function public.admin_metrics(date, date) to authenticated;
