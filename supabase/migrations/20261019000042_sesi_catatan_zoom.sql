-- Detail sesi: catatan tentor lebih lengkap + tautan Zoom per sesi
--
-- (1) session_notes.next_step — tugas/saran berikutnya untuk siswa (opsional).
-- (2) bookings.meeting_url — tautan pertemuan daring (khusus mode online).
--     PENTING: guard_text (Fase 10) menolak SEMUA tautan, jadi kolom ini
--     sengaja TIDAK dipasangi guard_text. Sebagai gantinya ada trigger
--     validasi ketat: hanya https + domain zoom.us / zoom.com.
-- (3) RPC set_session_meeting_url — hanya tutor pemilik sesi (atau admin).
-- (4) RPC save_session_note diperluas dengan p_next_step (3 argumen lama
--     tetap bisa dipanggil karena parameter baru punya nilai default).
-- (5) bookings_visible ditambah kolom meeting_url di bagian akhir.

alter table public.session_notes add column if not exists next_step text;

alter table public.bookings add column if not exists meeting_url text;
alter table public.bookings add column if not exists meeting_url_set_at timestamptz;

comment on column public.bookings.meeting_url is
  'Tautan Zoom sesi daring. Ditulis lewat set_session_meeting_url; divalidasi domain, BUKAN lewat guard_text.';

-- Apakah teks ini tautan Zoom yang sah (null = kosong, dianggap sah).
create or replace function public.is_zoom_url(p_url text)
returns boolean
language sql
immutable
as $$
  select p_url is null
     or lower(p_url) ~
        '^https://([a-z0-9-]+\.)*zoom\.(us|com)(:[0-9]+)?(/[^[:space:]]*)?$'
$$;

comment on function public.is_zoom_url(text) is
  'Validasi tautan Zoom: wajib https, host berakhir zoom.us/zoom.com, tanpa spasi.';

-- Penjaga semua jalur tulis (RPC, dashboard, SQL manual): hanya https Zoom,
-- dan hanya untuk sesi daring — agar invariannya sama seperti di RPC.
create or replace function public.guard_meeting_url()
returns trigger
language plpgsql
as $$
begin
  if new.meeting_url is null then
    return new;
  end if;
  if new.mode <> 'online' then
    raise exception 'Tautan Zoom hanya untuk sesi online' using errcode = '22023';
  end if;
  if not public.is_zoom_url(new.meeting_url) then
    raise exception 'Tautan harus berupa https://...zoom.us atau zoom.com'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_meeting_url() from public, anon, authenticated;

drop trigger if exists guard_meeting_url on public.bookings;
create trigger guard_meeting_url
  before insert or update of meeting_url, mode on public.bookings
  for each row execute function public.guard_meeting_url();

-- Tutor mengisi/menghapus tautan Zoom satu sesi. Isi tautan tidak ditulis ke
-- audit_logs (hanya status terisi/kosong) agar tautan tidak bocor ke log.
create or replace function public.set_session_meeting_url(
  p_booking uuid,
  p_url text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings;
  v_url text;
begin
  select * into v_b from public.bookings where id = p_booking for update;
  if v_b.id is null then
    raise exception 'Booking tidak ditemukan' using errcode = '22023';
  end if;
  if v_b.tutor_id <> auth.uid() and not public.is_admin() then
    raise exception 'Hanya tutor pemilik sesi' using errcode = '42501';
  end if;

  v_url := nullif(trim(coalesce(p_url, '')), '');
  if v_url is not null then
    if v_b.mode <> 'online' then
      raise exception 'Tautan Zoom hanya untuk sesi online' using errcode = '22023';
    end if;
    if not public.is_zoom_url(v_url) then
      raise exception 'Tautan harus berupa https://...zoom.us atau zoom.com'
        using errcode = '22023';
    end if;
  end if;

  update public.bookings
     set meeting_url = v_url,
         meeting_url_set_at = case when v_url is null then null else now() end
   where id = p_booking;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'booking.meeting_url', 'bookings', p_booking::text,
          jsonb_build_object('set', v_url is not null));
end;
$$;

revoke all on function public.set_session_meeting_url(uuid, text) from public, anon;
grant execute on function public.set_session_meeting_url(uuid, text) to authenticated;

-- Catatan sesi: tambah kolom tugas/saran berikutnya.
drop function if exists public.save_session_note(uuid, text, text);

create or replace function public.save_session_note(
  p_booking uuid,
  p_material text,
  p_progress text default null,
  p_next_step text default null
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

  insert into public.session_notes (booking_id, tutor_id, material, progress, next_step)
  values (p_booking, v_tutor, p_material, p_progress, p_next_step)
  on conflict (booking_id) do update
    set material = excluded.material,
        progress = excluded.progress,
        next_step = excluded.next_step;
end;
$$;

revoke all on function public.save_session_note(uuid, text, text, text) from public, anon;
grant execute on function public.save_session_note(uuid, text, text, text) to authenticated;

-- Penjaga teks (nomor/email/tautan dilarang) juga berlaku untuk tugas/saran.
drop trigger if exists guard_session_notes on public.session_notes;
create trigger guard_session_notes
  before insert or update of material, progress, next_step on public.session_notes
  for each row execute function public.enforce_text_guard('material', 'progress', 'next_step');

-- Tautan Zoom perlu terbaca peserta (dan admin) lewat view yang sama.
-- Sembunyikan sebelum lunas, sama seperti `address`.
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
  b.reschedule_count,
  case
    when b.status in ('pending_payment', 'cancelled', 'expired') then null
    else b.meeting_url
  end as meeting_url
from public.bookings b
where b.student_id = auth.uid()
   or b.tutor_id = auth.uid()
   or public.is_admin();

revoke select on public.bookings from anon, authenticated;
grant select on public.bookings_visible to authenticated;

comment on view public.bookings_visible is
  'Booking milik sendiri (siswa/tutor) + admin; tanpa kolom bagi hasil. address & meeting_url hanya terbuka pasca-bayar.';
