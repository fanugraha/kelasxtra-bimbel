-- Paket soal (urutan soal tetap) + 1 paket coba GRATIS untuk siswa yang belum
-- berlangganan. Diterapkan lewat `supabase db query --linked -f` (bukan
-- `db push`, lihat catatan jebakan migrasi), lalu dicatat di riwayat migrasi.
--
-- Aturan akses:
-- - Paket `is_free` boleh dikerjakan tanpa langganan; paket lain & latihan
--   per topik (`start_attempt`) tetap wajib langganan aktif.
-- - Siswa tidak membaca tabel soal; jumlah soal per topik lewat
--   `bank_soal_catalog()` (security definer, hanya angka).
-- - Penilaian tetap lewat `submit_attempt` (statistik topik ikut diperbarui).

-- ============ Paket soal ============
create table if not exists public.question_packs (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  subject_id  uuid not null references public.subjects (id) on delete restrict,
  topic_id    uuid references public.topics (id) on delete set null,
  jenjang     text not null references public.levels (code),
  is_free     boolean not null default false,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists public.question_pack_items (
  pack_id     uuid not null references public.question_packs (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  position    int not null,
  primary key (pack_id, question_id)
);

alter table public.question_packs enable row level security;
alter table public.question_pack_items enable row level security;

drop policy if exists "question_packs: baca aktif" on public.question_packs;
create policy "question_packs: baca aktif"
  on public.question_packs for select to authenticated using (active);
drop policy if exists "question_packs: admin kelola" on public.question_packs;
create policy "question_packs: admin kelola"
  on public.question_packs for all
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "question_pack_items: admin kelola" on public.question_pack_items;
create policy "question_pack_items: admin kelola"
  on public.question_pack_items for all
  using (public.is_admin()) with check (public.is_admin());

alter table public.attempts
  add column if not exists pack_id uuid references public.question_packs (id) on delete set null;
create index if not exists attempts_pack_idx on public.attempts (student_id, pack_id);

-- ============ RPC: mulai paket ============
create or replace function public.start_pack_attempt(p_pack uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pack public.question_packs;
  v_attempt uuid;
  v_questions jsonb;
  v_count int;
begin
  if v_uid is null then
    raise exception 'Tidak terautentikasi' using errcode = '42501';
  end if;
  select * into v_pack from public.question_packs where id = p_pack and active;
  if v_pack.id is null then
    raise exception 'Paket soal tidak ditemukan' using errcode = '22023';
  end if;
  if not v_pack.is_free and not public.has_active_subscription(v_uid) then
    raise exception 'Langganan tidak aktif' using errcode = '42501';
  end if;

  select jsonb_agg(x order by x.position) into v_questions from (
    select q.id, q.type, q.current_version as version,
           qv.body, qv.options, qv.image_url, i.position
    from public.question_pack_items i
    join public.questions q on q.id = i.question_id and q.status = 'published'
    join public.question_versions qv
      on qv.question_id = q.id and qv.version = q.current_version
    where i.pack_id = v_pack.id
  ) x;

  v_count := coalesce(jsonb_array_length(v_questions), 0);
  if v_count = 0 then
    raise exception 'Paket ini belum berisi soal' using errcode = '22023';
  end if;

  insert into public.attempts
    (student_id, mode, subject_id, topic_id, jenjang, total_questions, pack_id)
  values
    (v_uid, 'latihan', v_pack.subject_id, v_pack.topic_id, v_pack.jenjang, v_count, v_pack.id)
  returning id into v_attempt;

  return jsonb_build_object('attempt_id', v_attempt, 'questions', v_questions);
end;
$$;

revoke execute on function public.start_pack_attempt(uuid) from public;
revoke execute on function public.start_pack_attempt(uuid) from anon;
grant execute on function public.start_pack_attempt(uuid) to authenticated;

-- ============ RPC: katalog topik + jumlah soal terbit ============
create or replace function public.bank_soal_catalog()
returns table (
  topic_id uuid,
  topic_name text,
  subject_id uuid,
  subject_name text,
  jenjang text,
  question_count int
)
language sql
stable
security definer
set search_path = public
as $$
  select t.id, t.name, s.id, s.name, t.jenjang,
         (select count(*)::int from public.questions q
           where q.topic_id = t.id and q.status = 'published')
  from public.topics t
  join public.subjects s on s.id = t.subject_id
  where t.active
  order by s.name, t.name;
$$;

revoke execute on function public.bank_soal_catalog() from public;
revoke execute on function public.bank_soal_catalog() from anon;
grant execute on function public.bank_soal_catalog() to authenticated;

-- ============ Isi: 5 soal Trigonometri baru + paket gratis 10 soal ============
do $$
declare
  v_topic uuid;
  v_subject uuid;
  v_pack uuid;
  v_q uuid;
  v_pos int := 0;
  r record;
begin
  select t.id, t.subject_id into v_topic, v_subject
  from public.topics t join public.subjects s on s.id = t.subject_id
  where t.name = 'Trigonometri' and s.name = 'Matematika' and t.jenjang = 'SMA'
  limit 1;
  if v_topic is null then
    raise notice 'Topik Trigonometri SMA tidak ada — isi paket dilewati';
    return;
  end if;
  if exists (select 1 from public.question_packs where is_free and topic_id = v_topic) then
    raise notice 'Paket gratis Trigonometri sudah ada — dilewati';
    return;
  end if;

  for r in select * from (values
    ('Nilai dari sin 45 derajat adalah ...',
     '[{"key":"A","text":"1/2"},{"key":"B","text":"akar2/2"},{"key":"C","text":"akar3/2"},{"key":"D","text":"1"}]',
     'B', 'sin 45 derajat = akar2/2 (segitiga siku-siku sama kaki).'),
    ('Nilai dari cos 0 derajat adalah ...',
     '[{"key":"A","text":"0"},{"key":"B","text":"1/2"},{"key":"C","text":"1"},{"key":"D","text":"-1"}]',
     'C', 'Pada sudut 0 derajat titiknya (1, 0), jadi cos 0 = 1.'),
    ('Jika sin A = 3/5 dan A sudut lancip, nilai cos A adalah ...',
     '[{"key":"A","text":"3/4"},{"key":"B","text":"4/5"},{"key":"C","text":"5/4"},{"key":"D","text":"4/3"}]',
     'B', 'Segitiga 3-4-5: depan 3, miring 5, maka samping 4. cos A = 4/5.'),
    ('Nilai dari sin 30 derajat + cos 60 derajat adalah ...',
     '[{"key":"A","text":"1/2"},{"key":"B","text":"1"},{"key":"C","text":"akar3"},{"key":"D","text":"2"}]',
     'B', 'sin 30 = 1/2 dan cos 60 = 1/2, jumlahnya 1.'),
    ('Nilai dari cos 120 derajat adalah ...',
     '[{"key":"A","text":"1/2"},{"key":"B","text":"-1/2"},{"key":"C","text":"akar3/2"},{"key":"D","text":"-akar3/2"}]',
     'B', 'cos 120 = cos (180 - 60) = -cos 60 = -1/2 (kuadran II, cos negatif).')
  ) as v(body, options, answer, explanation)
  loop
    insert into public.questions (subject_id, topic_id, jenjang, type, status, current_version)
    values (v_subject, v_topic, 'SMA', 'pg', 'published', 1)
    returning id into v_q;
    insert into public.question_versions (question_id, version, body, options, answer, explanation)
    values (v_q, 1, r.body, r.options::jsonb, r.answer, r.explanation);
  end loop;

  insert into public.question_packs (title, subject_id, topic_id, jenjang, is_free)
  values ('Paket Coba Gratis: Trigonometri', v_subject, v_topic, 'SMA', true)
  returning id into v_pack;

  -- 10 soal: urut dari yang paling dasar (soal lama dulu, lalu yang baru).
  for r in
    select q.id from public.questions q
    where q.topic_id = v_topic and q.status = 'published'
    order by q.created_at, q.id
    limit 10
  loop
    v_pos := v_pos + 1;
    insert into public.question_pack_items (pack_id, question_id, position)
    values (v_pack, r.id, v_pos);
  end loop;
end;
$$;

-- ============ RPC: daftar paket + jumlah soal + nilai terakhir siswa ============
create or replace function public.my_question_packs()
returns table (
  id uuid,
  title text,
  subject_name text,
  topic_name text,
  jenjang text,
  is_free boolean,
  question_count int,
  last_correct int,
  last_total int,
  last_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.title, s.name, t.name, p.jenjang, p.is_free,
         (select count(*)::int from public.question_pack_items i
            join public.questions q on q.id = i.question_id and q.status = 'published'
           where i.pack_id = p.id),
         a.correct_count, a.total_questions, a.finished_at
  from public.question_packs p
  join public.subjects s on s.id = p.subject_id
  left join public.topics t on t.id = p.topic_id
  left join lateral (
    select at.correct_count, at.total_questions, at.finished_at
    from public.attempts at
    where at.pack_id = p.id and at.student_id = auth.uid()
      and at.finished_at is not null
    order by at.finished_at desc
    limit 1
  ) a on true
  where p.active
  order by p.is_free desc, s.name, p.title;
$$;

revoke execute on function public.my_question_packs() from public;
revoke execute on function public.my_question_packs() from anon;
grant execute on function public.my_question_packs() to authenticated;
