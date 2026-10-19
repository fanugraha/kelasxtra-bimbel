-- Fase 14 — Poin siswa (pengganti refund uang).
--
-- Keputusan pemilik:
--   * Tidak ada pengembalian uang tunai untuk alasan apa pun.
--   * Satu-satunya pengembalian = POIN. 1 poin = Rp1, dipakai memotong
--     pembayaran berikutnya (paket/kelas grup).
--   * Poin OTOMATIS hanya saat tentor tidak hadir (`no_show_tutor`) pada sesi
--     satuan (dibayar uang). Sesi paket bukan poin: pertemuannya wajib diganti
--     tentor (`reschedule_no_show`), maksimal 7 hari setelah sesi gagal.
--   * Admin boleh memberi poin manual (jalur komplain) — nominal ditentukan
--     admin, bukan lagi "refund".
--
-- Yang diubah:
--   * tabel `student_credits` (buku besar poin, append-only)
--   * saldo: `student_credit_balance` / `my_credit_balance`
--   * pemicu poin pada `no_show_tutor`
--   * `resolve_complaint` → memberi poin (bukan refund), sesi tetap selesai
--   * `refund_package` → `cancel_package_with_credit`
--   * `refund_group_seat` → `cancel_group_seat_with_credit`

-- ============ 1. Buku besar poin ============
create table if not exists public.student_credits (
  id                  uuid primary key default gen_random_uuid(),
  student_id          uuid not null references public.students (id) on delete cascade,
  -- + = poin masuk, − = poin terpakai
  amount              integer not null check (amount <> 0),
  reason              text not null check (reason in (
                        'tutor_no_show', 'complaint', 'manual',
                        'package_cancel', 'group_cancel', 'checkout')),
  booking_id          uuid references public.bookings (id) on delete set null,
  package_purchase_id uuid references public.package_purchases (id) on delete set null,
  group_seat_id       uuid references public.group_seats (id) on delete set null,
  note                text,
  created_by          uuid references public.profiles (id) on delete set null,
  created_at          timestamptz not null default now(),
  check (
    (reason = 'checkout' and amount < 0)
    or (reason <> 'checkout' and amount > 0)
  )
);

create index if not exists student_credits_student_idx
  on public.student_credits (student_id, created_at desc);
create index if not exists student_credits_booking_idx
  on public.student_credits (booking_id);

-- Kompensasi tentor tidak hadir hanya sekali per sesi.
create unique index if not exists student_credits_no_show_once
  on public.student_credits (booking_id)
  where reason = 'tutor_no_show';

alter table public.student_credits enable row level security;

drop policy if exists "poin: siswa baca sendiri" on public.student_credits;
create policy "poin: siswa baca sendiri"
  on public.student_credits for select
  using (student_id = auth.uid() or public.is_admin());

drop trigger if exists guard_student_credits_note on public.student_credits;
create trigger guard_student_credits_note
  before insert or update of note on public.student_credits
  for each row execute function public.enforce_text_guard('note');

-- ============ 2. Saldo poin ============
create or replace function public.student_credit_balance(p_student uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v int;
begin
  if not public.is_admin()
     and auth.uid() is distinct from p_student
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Tidak boleh melihat saldo poin orang lain' using errcode = '42501';
  end if;
  select coalesce(sum(amount), 0)::int into v
  from public.student_credits where student_id = p_student;
  return coalesce(v, 0);
end;
$$;

revoke all on function public.student_credit_balance(uuid) from public;
grant execute on function public.student_credit_balance(uuid) to authenticated, service_role;

create or replace function public.my_credit_balance()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select public.student_credit_balance(auth.uid());
$$;

revoke all on function public.my_credit_balance() from public, anon;
grant execute on function public.my_credit_balance() to authenticated;

-- ============ 3. Kompensasi tentor tidak hadir ============
create or replace function public.apply_tutor_no_show(p_booking uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
begin
  select * into v_b from public.bookings where id = p_booking;
  if v_b.id is null or v_b.status <> 'no_show_tutor' then
    return;
  end if;
  if exists (
    select 1 from public.student_credits
    where booking_id = p_booking and reason = 'tutor_no_show'
  ) then
    return;
  end if;

  if v_b.package_purchase_id is null then
    -- Sesi satuan: poin = nilai yang dibayar.
    if v_b.amount_due > 0 then
      insert into public.student_credits
        (student_id, amount, reason, booking_id, note)
      values (v_b.student_id, v_b.amount_due, 'tutor_no_show', p_booking,
              'Tentor tidak hadir');
    end if;
    perform public.queue_notification(
      v_b.student_id, 'credit', 'Poin kompensasi masuk',
      format('Tentor tidak hadir. Rp%s masuk sebagai poin untuk potongan pembayaran berikutnya.',
             to_char(v_b.amount_due, 'FM999G999G999')),
      jsonb_build_object('booking_id', p_booking, 'amount', v_b.amount_due));
  else
    -- Sesi paket: bukan poin — pertemuan wajib diganti tentor (maks 7 hari).
    perform public.queue_notification(
      v_b.student_id, 'reschedule', 'Pertemuan wajib diganti',
      'Tentor tidak hadir. Pertemuan ini akan dijadwalkan ulang oleh tentor (paling lambat 7 hari).',
      jsonb_build_object('booking_id', p_booking));
    perform public.queue_notification(
      v_b.tutor_id, 'reschedule', 'Wajib menjadwalkan ulang pertemuan',
      'Kamu tidak hadir pada sesi ini. Wajib menjadwalkan ulang dalam 7 hari.',
      jsonb_build_object('booking_id', p_booking));
  end if;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'booking.no_show_compensation', 'bookings', p_booking::text,
          jsonb_build_object('package', v_b.package_purchase_id is not null,
                             'amount', v_b.amount_due));
end;
$$;

revoke all on function public.apply_tutor_no_show(uuid) from public, anon, authenticated;

create or replace function public.bookings_no_show_credit_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.apply_tutor_no_show(new.id);
  return new;
end;
$$;

revoke all on function public.bookings_no_show_credit_trigger() from public, anon, authenticated;

drop trigger if exists bookings_after_no_show on public.bookings;
create trigger bookings_after_no_show
  after update of status on public.bookings
  for each row
  when (new.status = 'no_show_tutor' and old.status is distinct from 'no_show_tutor')
  execute function public.bookings_no_show_credit_trigger();

-- ============ 4. Pertemuan pengganti (sesi paket) ============
create or replace function public.reschedule_no_show(
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
  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.status <> 'no_show_tutor' then
    raise exception 'Sesi ini bukan berstatus tentor tidak hadir' using errcode = '22023';
  end if;
  if v_b.package_purchase_id is null then
    raise exception 'Sesi satuan yang gagal sudah dikompensasi poin' using errcode = '22023';
  end if;
  if v_b.tutor_id <> auth.uid() and not public.is_admin() then
    raise exception 'Hanya tentor pemilik sesi atau admin' using errcode = '42501';
  end if;
  if now() > v_b.scheduled_at + interval '7 days' and not public.is_admin() then
    raise exception 'Batas 7 hari untuk menjadwalkan ulang sudah lewat' using errcode = '22023';
  end if;
  if p_new_at <= now() then
    raise exception 'Jadwal pengganti harus di masa depan' using errcode = '22023';
  end if;
  if p_new_at > now() + interval '14 days' then
    raise exception 'Jadwal pengganti maksimal 14 hari ke depan' using errcode = '22023';
  end if;
  if p_new_at > (select expires_at from public.package_purchases
                  where id = v_b.package_purchase_id) then
    raise exception 'Jadwal pengganti melewati masa berlaku paket' using errcode = '22023';
  end if;
  if not public.tutor_free_at(v_b.tutor_id, p_new_at, v_b.duration_minutes, v_b.mode) then
    raise exception 'Jadwal pengganti di luar jam ketersediaan tutor' using errcode = '22023';
  end if;
  if not public.slot_is_free(v_b.id, p_new_at, v_b.duration_minutes,
                             v_b.tutor_id, v_b.student_id) then
    raise exception 'Jadwal pengganti sudah terisi' using errcode = '22023';
  end if;

  perform public.guard_text(p_reason, 'booking.no_show_makeup_reason');

  update public.bookings
     set status = 'confirmed',
         scheduled_at = p_new_at,
         lock_expires_at = null
   where id = v_b.id;

  insert into public.booking_reschedules (booking_id, from_at, to_at, requested_by, reason)
  values (v_b.id, v_b.scheduled_at, p_new_at, auth.uid(),
          'Pengganti sesi gagal: ' || coalesce(nullif(trim(coalesce(p_reason, '')), ''), '-'));

  perform public.queue_notification(
    v_b.student_id, 'reschedule', 'Pertemuan pengganti dijadwalkan',
    format('Tentor menjadwalkan ulang pertemuan pada %s.',
           to_char(p_new_at at time zone 'Asia/Jakarta', 'DD Mon YYYY HH24:MI')),
    jsonb_build_object('booking_id', v_b.id));

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'booking.no_show_makeup', 'bookings', v_b.id::text,
          jsonb_build_object('scheduled_at', v_b.scheduled_at, 'status', v_b.status),
          jsonb_build_object('scheduled_at', p_new_at, 'reason', p_reason));

  return p_new_at;
end;
$$;

grant execute on function public.reschedule_no_show(uuid, timestamptz, text) to authenticated;

-- ============ 5. Poin manual oleh admin ============
create or replace function public.grant_student_credit(
  p_student uuid,
  p_amount integer,
  p_reason text,
  p_note text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Jumlah poin harus lebih dari 0' using errcode = '22023';
  end if;
  if p_reason not in ('complaint', 'manual') then
    raise exception 'Alasan poin tidak valid' using errcode = '22023';
  end if;

  insert into public.student_credits (student_id, amount, reason, note, created_by)
  values (p_student, p_amount, p_reason, p_note, auth.uid());

  perform public.queue_notification(
    p_student, 'credit', 'Poin ditambahkan',
    format('Rp%s poin ditambahkan ke akunmu dan bisa dipakai untuk pembayaran berikutnya.',
           to_char(p_amount, 'FM999G999G999')),
    '{}'::jsonb);
end;
$$;

grant execute on function public.grant_student_credit(uuid, integer, text, text) to authenticated;

-- ============ 6. Pemakaian poin saat checkout ============
-- Dipanggil Edge Function (service role) ketika siswa memilih memakai poin.
create or replace function public.spend_credits(
  p_student uuid,
  p_amount integer,
  p_note text default null,
  p_package_purchase_id uuid default null,
  p_group_seat_id uuid default null
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance int;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'Jumlah poin terpakai harus lebih dari 0' using errcode = '22023';
  end if;

  -- Serialkan per siswa agar dua checkout tidak memakai poin yang sama.
  perform pg_advisory_xact_lock(hashtext('credit:' || p_student::text));

  v_balance := public.student_credit_balance(p_student);
  if p_amount > v_balance then
    raise exception 'Saldo poin tidak cukup (tersedia %)', v_balance using errcode = '22023';
  end if;

  insert into public.student_credits
    (student_id, amount, reason, note, package_purchase_id, group_seat_id)
  values (p_student, -p_amount, 'checkout', p_note, p_package_purchase_id, p_group_seat_id);

  return v_balance - p_amount;
end;
$$;

revoke all on function public.spend_credits(uuid, integer, text, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.spend_credits(uuid, integer, text, uuid, uuid) to service_role;

-- ============ 7. Komplain: poin, bukan refund ============
alter table public.complaints
  add column if not exists credit_nominal integer not null default 0
    check (credit_nominal >= 0);

-- p_refund → p_credit: nama parameter berubah, jadi harus drop dulu.
drop function if exists public.resolve_complaint(uuid, text, text, integer);

create or replace function public.resolve_complaint(
  p_complaint uuid,
  p_status text,
  p_decision text,
  p_credit integer default 0
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
  if p_credit < 0 then
    raise exception 'Poin kompensasi tidak boleh negatif' using errcode = '22023';
  end if;

  select * into v_c from public.complaints where id = p_complaint for update;
  if v_c.id is null then
    raise exception 'Komplain tidak ditemukan' using errcode = '22023';
  end if;
  if v_c.status in ('resolved', 'rejected') then
    return;
  end if;

  select * into v_b from public.bookings where id = v_c.booking_id for update;
  if p_credit > v_b.amount_due then
    raise exception 'Poin melebihi nilai transaksi' using errcode = '22023';
  end if;

  update public.complaints
     set status = p_status,
         decision = p_decision,
         credit_nominal = case when p_status = 'resolved' then p_credit else 0 end,
         refund_nominal = 0,
         resolved_by = auth.uid(),
         resolved_at = now()
   where id = p_complaint;

  -- Sesi tetap dianggap selesai (tidak ada status 'refunded'); pihak yang
  -- dirugikan menerima poin sebagai ganti uang.
  update public.bookings set status = 'completed' where id = v_b.id;
  update public.tutor_earnings set status = 'belum_dibayar'
   where booking_id = v_b.id and status = 'ditahan';

  if p_status = 'resolved' and p_credit > 0 then
    insert into public.student_credits
      (student_id, amount, reason, booking_id, note, created_by)
    values (v_b.student_id, p_credit, 'complaint', v_b.id, p_decision, auth.uid());

    perform public.queue_notification(
      v_b.student_id, 'credit', 'Poin kompensasi komplain',
      format('Rp%s poin ditambahkan dari penyelesaian komplain.', to_char(p_credit, 'FM999G999G999')),
      jsonb_build_object('booking_id', v_b.id, 'complaint_id', p_complaint));
  end if;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'complaint.resolve', 'complaints', p_complaint::text,
          jsonb_build_object('status', p_status, 'credit', p_credit, 'booking_id', v_b.id));
end;
$$;

grant execute on function public.resolve_complaint(uuid, text, text, integer) to authenticated;

-- ============ 8. Batal paket / kursi grup → poin ============
create or replace function public.cancel_package_with_credit(
  p_package_id uuid,
  p_note text default null
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.package_purchases;
  v_credit integer;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;

  select * into v from public.package_purchases where id = p_package_id for update;
  if v.id is null then
    raise exception 'Paket tidak ditemukan' using errcode = '22023';
  end if;
  if v.status not in ('active', 'expired') then
    raise exception 'Paket tidak bisa dibatalkan (status %)', v.status using errcode = '22023';
  end if;

  -- Nilai sisa kuota (integer rupiah).
  v_credit := (v.price_total * (v.total_sesi - v.sesi_terpakai)) / v.total_sesi;

  update public.package_purchases
     set status = 'cancelled', refund_amount = 0
   where id = p_package_id;

  if v_credit > 0 then
    insert into public.student_credits
      (student_id, amount, reason, package_purchase_id, note, created_by)
    values (v.student_id, v_credit, 'package_cancel', p_package_id, p_note, auth.uid());

    perform public.queue_notification(
      v.student_id, 'credit', 'Paket dibatalkan, poin masuk',
      format('Rp%s poin ditambahkan (sisa kuota paket).', to_char(v_credit, 'FM999G999G999')),
      jsonb_build_object('package_purchase_id', p_package_id));
  end if;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'package.cancel_credit', 'package_purchases', p_package_id::text,
          jsonb_build_object('status', v.status, 'sesi_terpakai', v.sesi_terpakai),
          jsonb_build_object('credit', v_credit, 'status', 'cancelled'));

  return v_credit;
end;
$$;

grant execute on function public.cancel_package_with_credit(uuid, text) to authenticated;

drop function if exists public.refund_package(uuid);

create or replace function public.cancel_group_seat_with_credit(
  p_seat_id uuid,
  p_note text default null
) returns integer
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
    raise exception 'Kursi tidak bisa dibatalkan (status %)', v.status using errcode = '22023';
  end if;

  update public.group_seats
     set status = 'cancelled', refund_amount = 0
   where id = p_seat_id;

  -- Kursi aktif yang dibatalkan mengembalikan tempat di kelas.
  if v.status = 'active' then
    update public.group_classes
       set seats_taken = greatest(0, seats_taken - 1)
     where id = v.group_class_id and status in ('open', 'confirmed');
  end if;

  if v.price_paid > 0 then
    insert into public.student_credits
      (student_id, amount, reason, group_seat_id, note, created_by)
    values (v.student_id, v.price_paid, 'group_cancel', p_seat_id, p_note, auth.uid());

    perform public.queue_notification(
      v.student_id, 'credit', 'Kursi kelas dibatalkan, poin masuk',
      format('Rp%s poin ditambahkan.', to_char(v.price_paid, 'FM999G999G999')),
      jsonb_build_object('group_seat_id', p_seat_id));
  end if;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'group_seat.cancel_credit', 'group_seats', p_seat_id::text,
          jsonb_build_object('status', v.status),
          jsonb_build_object('credit', v.price_paid, 'status', 'cancelled'));

  return v.price_paid;
end;
$$;

grant execute on function public.cancel_group_seat_with_credit(uuid, text) to authenticated;

drop function if exists public.refund_group_seat(uuid);
