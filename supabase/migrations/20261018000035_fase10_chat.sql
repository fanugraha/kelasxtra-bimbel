-- ============================================================================
-- Fase 10 – Chat per tutor + penjaga kebocoran data (anti transaksi luar)
--   1. Penjaga teks: tolak kiriman berisi nomor HP, email, tautan, akun sosial,
--      ajakan bayar di luar aplikasi. Berlaku untuk semua teks buatan pengguna.
--   2. Percakapan per tutor (siswa–tutor) + pesan, belum dibaca, realtime.
--   3. Chat hanya boleh dimulai bila sudah ada sesi (booking) antara keduanya.
--
-- Catatan desain: penolakan lewat trigger memakai EXCEPTION sehingga baris
-- catatan pelanggaran ikut ter-rollback; karena itu chat (jalur utama) memakai
-- guard_check + balasan jsonb supaya catatan pelanggaran tetap tersimpan,
-- sedangkan jalur trigger tetap menolak + mencatat ke log server (raise log).
-- ============================================================================

-- ============ 1. Normalisasi + penjaga teks ============
create or replace function public.guard_compact(p_text text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text;
begin
  v := lower(coalesce(p_text, ''));
  v := regexp_replace(v, '\mnol\M|\mkosong\M', '0', 'g');
  v := regexp_replace(v, '\msatu\M', '1', 'g');
  v := regexp_replace(v, '\mdua\M', '2', 'g');
  v := regexp_replace(v, '\mtiga\M', '3', 'g');
  v := regexp_replace(v, '\mempat\M', '4', 'g');
  v := regexp_replace(v, '\mlima\M', '5', 'g');
  v := regexp_replace(v, '\menam\M', '6', 'g');
  v := regexp_replace(v, '\mtujuh\M', '7', 'g');
  v := regexp_replace(v, '\mdelapan\M', '8', 'g');
  v := regexp_replace(v, '\msembilan\M', '9', 'g');
  v := regexp_replace(v, '[^a-z0-9@.:/]', '', 'g');
  return v;
end;
$$;

create or replace function public.guard_loose_hit(p_text text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when lower(coalesce(p_text, '')) ~ '\mwhatsapp\M|\mtelegram\M|\mwechat\M'
      then 'akun pesan luar'
    when lower(coalesce(p_text, '')) ~ '\minstagram\M|\mfacebook\M|\mtiktok\M|@[a-z0-9._]{3,}'
      then 'akun media sosial'
    when lower(coalesce(p_text, '')) ~ '\mnorek\M|\mno rek\M|\mnomor rekening\M|\mrekening\M'
      then 'rekening'
    when lower(coalesce(p_text, '')) ~ '\mno wa\M|\mnomor wa\M|\mnomer wa\M|\mno hp\M|\mnomor hp\M|\mnomer hp\M|\mnohp\M'
      then 'nomor kontak'
    else null
  end;
$$;

-- Kata pembayaran/bank hanya ditandai bila disertai angka, supaya kalimat
-- pelajaran seperti "materi tentang dana pensiun" tidak ikut tertolak.
create or replace function public.guard_number_hit(p_loose text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when lower(coalesce(p_loose, '')) ~ '\mtransfer\M|\mtf\M' then 'ajakan transfer'
    when lower(coalesce(p_loose, '')) ~ '\mbca\M|\mbni\M|\mbri\M|\mmandiri\M|\mbsi\M|\mcimb\M|\mpermata\M' then 'nama bank'
    when lower(coalesce(p_loose, '')) ~ '\m(dana|ovo|gopay|shopeepay|qris|paypal|bitcoin|usdt)\M'
         and lower(coalesce(p_loose, '')) ~ '\m(bayar|kirim|transfer|tf|top ?up|isi ulang|via|lewat|pakai|pake)\M'
      then 'dompet digital'
    when lower(coalesce(p_loose, '')) ~ '\m(dana|ovo|gopay|shopeepay|qris|paypal|bitcoin|usdt)\M\s*[0-9]'
      then 'dompet digital'
    else null
  end;
$$;

-- Periksa teks. Mengembalikan null bila aman, atau alasan bila melanggar.
-- Bila melanggar, catatan pelanggaran disimpan (transaksi pemanggil tetap lanjut).
create or replace function public.guard_check(
  p_text text,
  p_context text default 'teks'
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_loose   text;
  v_compact text;
  v_phone   text;
  v_match   text;
begin
  if p_text is null or length(trim(p_text)) = 0 then
    return null;
  end if;

  v_loose   := lower(p_text);
  v_compact := public.guard_compact(p_text);
  v_phone   := translate(v_compact, 'o', '0');

  v_match := public.guard_loose_hit(p_text);

  if v_match is null
     and (v_phone ~ '(\+?62|0)8[0-9]{6,}' or v_compact ~ '[0-9]{9,}') then
    v_match := 'nomor panjang';
  end if;

  if v_match is null
     and v_compact ~ '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' then
    v_match := 'email';
  end if;

  if v_match is null
     and (v_compact ~ '(https?|ftp)://'
          or v_compact ~ 'www\.'
          or v_compact ~ 'wa\.me|t\.me|bit\.ly|linktr\.ee'
          or v_compact ~ '[a-z0-9-]{2,}\.(com|net|org|id|co|io|me|xyz|info|biz|site|online|shop|store|link|app|gg|tv|live|club|top)\b') then
    v_match := 'tautan';
  end if;

  if v_match is null and v_compact ~ '[0-9]' then
    v_match := public.guard_number_hit(v_loose);
  end if;

  if v_match is not null then
    insert into public.moderation_flags (actor_id, context, matched, excerpt)
    values (auth.uid(), coalesce(p_context, 'teks'), v_match, left(p_text, 200));
  end if;

  return v_match;
end;
$$;

-- Versi trigger: tolak dengan pesan yang jelas + catat ke log server.
create or replace function public.guard_text(
  p_text text,
  p_context text default 'teks'
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match text;
begin
  v_match := public.guard_check(p_text, p_context);
  if v_match is not null then
    raise log 'kx_guard context=% alasan=% cuplik=%',
      p_context, v_match, left(p_text, 80);
    raise exception
      'Untuk keamanan, nomor HP, email, tautan, atau ajakan transaksi di luar aplikasi tidak boleh dikirim.'
      using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.guard_check(text, text) from public, anon, authenticated;
revoke all on function public.guard_text(text, text) from public, anon, authenticated;
revoke all on function public.guard_compact(text) from public, anon, authenticated;
revoke all on function public.guard_loose_hit(text) from public, anon, authenticated;
revoke all on function public.guard_number_hit(text) from public, anon, authenticated;

create or replace function public.enforce_text_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_col text;
  v_val text;
begin
  foreach v_col in array tg_argv loop
    v_val := to_jsonb(new) ->> v_col;
    perform public.guard_text(v_val, tg_table_name || '.' || v_col);
  end loop;
  return new;
end;
$$;

revoke all on function public.enforce_text_guard() from public, anon, authenticated;

-- ============ 2. Tabel percakapan & moderasi ============
create table if not exists public.conversations (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references public.students (id) on delete cascade,
  tutor_id        uuid not null references public.tutors (id) on delete cascade,
  last_message_at timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  unique (student_id, tutor_id)
);

create index if not exists conversations_student_idx
  on public.conversations (student_id, last_message_at desc);
create index if not exists conversations_tutor_idx
  on public.conversations (tutor_id, last_message_at desc);

create table if not exists public.conversation_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id       uuid not null references public.profiles (id) on delete cascade,
  body            text not null check (length(trim(body)) > 0),
  flagged         boolean not null default false,
  read_at         timestamptz,
  created_at      timestamptz not null default now()
);

create index if not exists conversation_messages_idx
  on public.conversation_messages (conversation_id, created_at);

create table if not exists public.moderation_flags (
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid references public.profiles (id) on delete set null,
  context     text not null,
  matched     text,
  excerpt     text,
  created_at  timestamptz not null default now(),
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  note        text
);

create index if not exists moderation_flags_created_idx
  on public.moderation_flags (created_at desc);

-- Penjaga dipasang ke semua teks buatan pengguna (termasuk jalur dashboard).
drop trigger if exists guard_tutors_bio on public.tutors;
create trigger guard_tutors_bio
  before insert or update of bio on public.tutors
  for each row execute function public.enforce_text_guard('bio');

drop trigger if exists guard_session_notes on public.session_notes;
create trigger guard_session_notes
  before insert or update of material, progress on public.session_notes
  for each row execute function public.enforce_text_guard('material', 'progress');

drop trigger if exists guard_reviews_comment on public.reviews;
create trigger guard_reviews_comment
  before insert or update of comment on public.reviews
  for each row execute function public.enforce_text_guard('comment');

drop trigger if exists guard_complaints_body on public.complaints;
create trigger guard_complaints_body
  before insert or update of body on public.complaints
  for each row execute function public.enforce_text_guard('body');

drop trigger if exists guard_thread_messages on public.thread_messages;
create trigger guard_thread_messages
  before insert on public.thread_messages
  for each row execute function public.enforce_text_guard('body');

drop trigger if exists guard_conversation_messages on public.conversation_messages;
create trigger guard_conversation_messages
  before insert on public.conversation_messages
  for each row execute function public.enforce_text_guard('body');

-- send_booking_message (chat lama per sesi): sensor diganti penolakan.
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

  v_thread := public.ensure_booking_thread(p_booking);

  insert into public.thread_messages (thread_id, sender_id, body, flagged)
  values (v_thread, auth.uid(), trim(p_body), false)
  returning id into v_id;

  return v_id;
end;
$$;

-- ============ 3. RPC percakapan ============
-- Buka/lanjutkan percakapan (tutor bagi siswa, siswa bagi tutor). Wajib sudah
-- ada booking antara keduanya.
create or replace function public.ensure_conversation(p_other uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student uuid;
  v_tutor   uuid;
  v_id      uuid;
begin
  if auth.uid() is null then
    raise exception 'Harus masuk dulu' using errcode = '42501';
  end if;

  if exists (select 1 from public.students where id = auth.uid()) then
    v_student := auth.uid();
    v_tutor := p_other;
  elsif exists (select 1 from public.tutors where id = auth.uid()) then
    v_tutor := auth.uid();
    v_student := p_other;
  else
    raise exception 'Hanya siswa atau tutor' using errcode = '42501';
  end if;

  select id into v_id
  from public.conversations
  where student_id = v_student and tutor_id = v_tutor;

  if v_id is not null then
    return v_id;
  end if;

  if not exists (
    select 1 from public.bookings
    where student_id = v_student and tutor_id = v_tutor
  ) then
    raise exception 'Chat tersedia setelah kamu memesan sesi dengan tutor ini.'
      using errcode = '42501';
  end if;

  insert into public.conversations (student_id, tutor_id)
  values (v_student, v_tutor)
  on conflict (student_id, tutor_id) do nothing;

  select id into v_id
  from public.conversations
  where student_id = v_student and tutor_id = v_tutor;

  return v_id;
end;
$$;

-- Kirim pesan. Mengembalikan jsonb {ok, message_id, conversation_id, error}
-- supaya penolakan bisa dicatat tanpa ikut ter-rollback.
drop function if exists public.send_conversation_message(uuid, text);
create or replace function public.send_conversation_message(
  p_other uuid,
  p_body text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv   uuid;
  v_id     uuid;
  v_peer   uuid;
  v_name   text;
  v_body   text;
  v_reason text;
begin
  v_conv := public.ensure_conversation(p_other);

  v_body := trim(coalesce(p_body, ''));
  if v_body = '' then
    return jsonb_build_object('ok', false, 'error', 'Pesan kosong');
  end if;
  if length(v_body) > 2000 then
    return jsonb_build_object('ok', false, 'error', 'Pesan maksimal 2000 karakter');
  end if;

  v_reason := public.guard_check(v_body, 'conversation_messages.body');
  if v_reason is not null then
    raise log 'kx_guard chat alasan=% cuplik=%', v_reason, left(v_body, 80);
    return jsonb_build_object(
      'ok', false,
      'error', 'Untuk keamanan, nomor HP, email, tautan, atau ajakan transaksi di luar aplikasi tidak boleh dikirim.'
    );
  end if;

  insert into public.conversation_messages (conversation_id, sender_id, body)
  values (v_conv, auth.uid(), v_body)
  returning id into v_id;

  update public.conversations set last_message_at = now() where id = v_conv;

  select case when student_id = auth.uid() then tutor_id else student_id end
  into v_peer
  from public.conversations where id = v_conv;

  v_name := coalesce((select full_name from public.profiles where id = auth.uid()), 'Pesan baru');
  perform public.queue_notification(
    v_peer, 'chat.message', v_name, left(v_body, 120),
    jsonb_build_object('conversation_id', v_conv)
  );

  return jsonb_build_object('ok', true, 'message_id', v_id, 'conversation_id', v_conv);
end;
$$;

create or replace function public.mark_conversation_read(p_conversation uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.conversations
    where id = p_conversation
      and (student_id = auth.uid() or tutor_id = auth.uid())
  ) then
    raise exception 'Bukan peserta percakapan' using errcode = '42501';
  end if;

  update public.conversation_messages
  set read_at = now()
  where conversation_id = p_conversation
    and sender_id <> auth.uid()
    and read_at is null;
end;
$$;

revoke all on function public.ensure_conversation(uuid) from public, anon;
revoke all on function public.send_conversation_message(uuid, text) from public, anon;
revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.ensure_conversation(uuid) to authenticated;
grant execute on function public.send_conversation_message(uuid, text) to authenticated;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- ============ 4. RLS ============
alter table public.conversations enable row level security;
alter table public.conversation_messages enable row level security;
alter table public.moderation_flags enable row level security;

drop policy if exists "conversations: peserta baca" on public.conversations;
create policy "conversations: peserta baca"
  on public.conversations for select
  using (student_id = auth.uid() or tutor_id = auth.uid() or public.is_admin());

drop policy if exists "conversation messages: peserta baca" on public.conversation_messages;
create policy "conversation messages: peserta baca"
  on public.conversation_messages for select
  using (exists (
    select 1 from public.conversations c
    where c.id = conversation_id
      and (c.student_id = auth.uid() or c.tutor_id = auth.uid())
  ) or public.is_admin());

drop policy if exists "moderation: admin baca" on public.moderation_flags;
create policy "moderation: admin baca"
  on public.moderation_flags for select
  using (public.is_admin());

grant select on public.conversations to authenticated;
grant select on public.conversation_messages to authenticated;
grant select on public.moderation_flags to authenticated;

-- Daftar percakapan: view ini milik pemilik skema (melewati RLS tabel dasar)
-- sehingga baris disaring eksplisit dengan auth.uid(). Hanya nama + avatar
-- lawan bicara yang dibuka — tidak pernah nomor HP/email.
drop view if exists public.my_conversations;
create view public.my_conversations as
select
  c.id,
  c.student_id,
  c.tutor_id,
  case when c.student_id = auth.uid() then c.tutor_id else c.student_id end as peer_id,
  c.last_message_at,
  case when c.student_id = auth.uid() then t.full_name else sp.full_name end as peer_name,
  case when c.student_id = auth.uid() then t.photo_url else sp.avatar_url end as peer_avatar,
  (select m.body from public.conversation_messages m
    where m.conversation_id = c.id order by m.created_at desc limit 1) as last_body,
  (select count(*) from public.conversation_messages m
    where m.conversation_id = c.id
      and m.sender_id <> auth.uid()
      and m.read_at is null) as unread
from public.conversations c
join public.tutors t on t.id = c.tutor_id
join public.profiles sp on sp.id = c.student_id
where c.student_id = auth.uid() or c.tutor_id = auth.uid();

revoke all on public.my_conversations from anon, public;
grant select on public.my_conversations to authenticated;

-- ============ 5. Realtime ============
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversation_messages'
  ) then
    alter publication supabase_realtime add table public.conversation_messages;
  end if;
end;
$$;

-- ============ 6. Pindahkan riwayat chat lama ke percakapan ============
insert into public.conversations (student_id, tutor_id, created_at, last_message_at)
select b.student_id,
       b.tutor_id,
       min(bt.created_at),
       coalesce(max(tm.created_at), min(bt.created_at))
from public.booking_threads bt
join public.bookings b on b.id = bt.booking_id
left join public.thread_messages tm on tm.thread_id = bt.id
group by b.student_id, b.tutor_id
on conflict (student_id, tutor_id) do nothing;

insert into public.conversation_messages
  (id, conversation_id, sender_id, body, flagged, created_at)
select tm.id, c.id, tm.sender_id, tm.body, tm.flagged, tm.created_at
from public.thread_messages tm
join public.booking_threads bt on bt.id = tm.thread_id
join public.bookings b on b.id = bt.booking_id
join public.conversations c
  on c.student_id = b.student_id and c.tutor_id = b.tutor_id
on conflict (id) do nothing;

update public.conversations c
set last_message_at = coalesce(
  (select max(m.created_at) from public.conversation_messages m where m.conversation_id = c.id),
  c.created_at
);
