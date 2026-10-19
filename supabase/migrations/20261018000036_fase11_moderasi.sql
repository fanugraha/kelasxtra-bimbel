-- Fase 11 — Moderasi: catatan pelanggaran ditindaklanjuti dari dashboard.
-- (1) Setiap catatan menyimpan rujukan tabel + id agar admin bisa membuka
--     konteks (mis. percakapan yang memicunya).
-- (2) Penjaga teks mengisi rujukan itu.
-- (3) RPC admin: tandai ditinjau + kirim peringatan (berjejak di audit_logs).
-- Perintah tangguhkan tutor tetap lewat fungsi `manage-tutor` (sudah ada).

-- ============ 1. Rujukan pada catatan pelanggaran ============
alter table public.moderation_flags
  add column if not exists ref_table text,
  add column if not exists ref_id    uuid;

create index if not exists moderation_flags_open_idx
  on public.moderation_flags (created_at desc)
  where reviewed_at is null;

-- ============ 2. Penjaga teks mengisi rujukan ============
drop function if exists public.guard_check(text, text);
drop function if exists public.guard_text(text, text);

create or replace function public.guard_check(
  p_text      text,
  p_context   text default 'teks',
  p_ref_table text default null,
  p_ref_id    uuid default null
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
    insert into public.moderation_flags
      (actor_id, context, matched, excerpt, ref_table, ref_id)
    values
      (auth.uid(), coalesce(p_context, 'teks'), v_match, left(p_text, 200),
       p_ref_table, p_ref_id);
  end if;

  return v_match;
end;
$$;

-- Versi trigger: tolak dengan pesan yang jelas + catat ke log server.
create or replace function public.guard_text(
  p_text      text,
  p_context   text default 'teks',
  p_ref_table text default null,
  p_ref_id    uuid default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match text;
begin
  v_match := public.guard_check(p_text, p_context, p_ref_table, p_ref_id);
  if v_match is not null then
    raise log 'kx_guard context=% alasan=% cuplik=%',
      p_context, v_match, left(p_text, 80);
    raise exception
      'Untuk keamanan, nomor HP, email, tautan, atau ajakan transaksi di luar aplikasi tidak boleh dikirim.'
      using errcode = '22023';
  end if;
end;
$$;

create or replace function public.enforce_text_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_col text;
  v_val text;
  v_id  uuid;
begin
  v_id := nullif(to_jsonb(new) ->> 'id', '')::uuid;
  foreach v_col in array tg_argv loop
    v_val := to_jsonb(new) ->> v_col;
    perform public.guard_text(v_val, tg_table_name || '.' || v_col, tg_table_name, v_id);
  end loop;
  return new;
end;
$$;

revoke all on function public.guard_check(text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.guard_text(text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.enforce_text_guard() from public, anon, authenticated;

-- ============ 3. RPC chat mencatat percakapan yang memicu ============
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

  v_reason := public.guard_check(v_body, 'conversation_messages.body',
                                 'conversations', v_conv);
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

-- ============ 4. RPC admin untuk tindak lanjut ============
create or replace function public.admin_review_flag(
  p_flag uuid,
  p_note text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_f public.moderation_flags;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;

  select * into v_f from public.moderation_flags where id = p_flag for update;
  if v_f.id is null then
    raise exception 'Catatan tidak ditemukan' using errcode = '22023';
  end if;

  update public.moderation_flags
     set reviewed_by = auth.uid(),
         reviewed_at = now(),
         note = coalesce(nullif(trim(coalesce(p_note, '')), ''), note)
   where id = p_flag;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'moderation.review', 'moderation_flags', p_flag::text,
          jsonb_build_object('reviewed_at', v_f.reviewed_at),
          jsonb_build_object('note', p_note, 'matched', v_f.matched,
                             'actor_id', v_f.actor_id));
end;
$$;
grant execute on function public.admin_review_flag(uuid, text) to authenticated;

create or replace function public.admin_warn_user(
  p_user   uuid,
  p_reason text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'Alasan peringatan wajib' using errcode = '22023';
  end if;

  select full_name into v_name from public.profiles where id = p_user;
  if v_name is null then
    raise exception 'Pengguna tidak ditemukan' using errcode = '22023';
  end if;

  perform public.queue_notification(
    p_user, 'moderation.warning', 'Peringatan dari Kelasxtra',
    trim(p_reason), jsonb_build_object('from', 'admin')
  );

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'moderation.warn', 'profiles', p_user::text,
          jsonb_build_object('reason', trim(p_reason), 'name', v_name));
end;
$$;
grant execute on function public.admin_warn_user(uuid, text) to authenticated;

-- Hardening: RPC moderasi hanya untuk pengguna yang masuk (dicek is_admin()
-- di dalam fungsi). Cabut akses anon/PUBLIC seperti fungsi sensitif lain.
revoke execute on function public.admin_review_flag(uuid, text) from public, anon;
revoke execute on function public.admin_warn_user(uuid, text) from public, anon;
