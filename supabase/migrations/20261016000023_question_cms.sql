-- Fase 5 (bagian 2) — CMS soal: baca gambar untuk siswa + RPC simpan/ubah status.
-- Mengedit soal = membuat VERSI BARU (riwayat tak rusak), dijaga di server.

-- Siswa (authenticated) boleh membaca gambar soal agar bisa ditampilkan saat latihan.
create policy "question-assets: baca authenticated"
  on storage.objects for select
  using (bucket_id = 'question-assets' and auth.role() = 'authenticated');

-- Simpan soal (baru) atau tambah versi baru (edit). Admin saja.
create or replace function public.admin_save_question(
  p_question_id uuid,
  p_subject uuid,
  p_topic uuid,
  p_jenjang text,
  p_type text,
  p_body text,
  p_options jsonb,
  p_answer text,
  p_explanation text,
  p_image_path text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_next int;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_type not in ('pg', 'isian') then
    raise exception 'Tipe soal tidak valid' using errcode = '22023';
  end if;
  if p_body is null or length(trim(p_body)) = 0 then
    raise exception 'Isi soal wajib' using errcode = '22023';
  end if;
  if p_answer is null or length(trim(p_answer)) = 0 then
    raise exception 'Kunci jawaban wajib' using errcode = '22023';
  end if;

  if p_question_id is null then
    insert into public.questions
      (subject_id, topic_id, jenjang, type, status, current_version, created_by)
    values
      (p_subject, p_topic, p_jenjang, p_type, 'draft', 1, auth.uid())
    returning id into v_id;

    insert into public.question_versions
      (question_id, version, body, options, answer, explanation, image_url)
    values
      (v_id, 1, p_body, p_options, p_answer, p_explanation, p_image_path);

    return v_id;
  end if;

  select current_version into v_next from public.questions
   where id = p_question_id for update;
  if v_next is null then
    raise exception 'Soal tidak ditemukan' using errcode = '22023';
  end if;
  v_next := v_next + 1;

  insert into public.question_versions
    (question_id, version, body, options, answer, explanation, image_url)
  values
    (p_question_id, v_next, p_body, p_options, p_answer, p_explanation, p_image_path);

  update public.questions
     set subject_id = p_subject,
         topic_id = p_topic,
         jenjang = p_jenjang,
         type = p_type,
         current_version = v_next
   where id = p_question_id;

  return p_question_id;
end;
$$;

revoke all on function public.admin_save_question(uuid, uuid, uuid, text, text, text, jsonb, text, text, text)
  from public, anon, authenticated;
grant execute on function public.admin_save_question(uuid, uuid, uuid, text, text, text, jsonb, text, text, text)
  to authenticated;

-- Ubah status soal (draft → review → published → archived).
create or replace function public.admin_set_question_status(
  p_question_id uuid,
  p_status text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_status not in ('draft', 'review', 'published', 'archived') then
    raise exception 'Status tidak valid' using errcode = '22023';
  end if;

  update public.questions set status = p_status where id = p_question_id;
  if not found then
    raise exception 'Soal tidak ditemukan' using errcode = '22023';
  end if;

  insert into public.audit_logs (actor_id, action, entity, entity_id, after_data)
  values (auth.uid(), 'question.status', 'questions', p_question_id::text,
          jsonb_build_object('status', p_status));
end;
$$;

revoke all on function public.admin_set_question_status(uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_set_question_status(uuid, text) to authenticated;
