-- Fase 5 — Bank Soal (bagian 1: skema)
-- Langganan: manual bulanan (Snap) dengan tenggang 3 hari; auto-potong kartu menyusul.
-- Kunci jawaban TIDAK pernah bocor ke client: soal diberikan lewat RPC, penilaian di server.

-- ============ Paket langganan ============
create table public.subscription_plans (
  code        text primary key,
  name        text not null,
  price       integer not null check (price >= 0),
  period_days integer not null default 30 check (period_days > 0),
  grace_days  integer not null default 3 check (grace_days >= 0),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

insert into public.subscription_plans (code, name, price, period_days, grace_days)
values ('bank_soal', 'Bank Soal', 29000, 30, 3)
on conflict (code) do nothing;

alter table public.subscription_plans enable row level security;
create policy "plans: baca publik"
  on public.subscription_plans for select using (active);
create policy "plans: admin kelola"
  on public.subscription_plans for all
  using (public.is_admin()) with check (public.is_admin());

-- ============ Langganan siswa ============
create table public.subscriptions (
  id                      uuid primary key default gen_random_uuid(),
  student_id              uuid not null references public.students (id) on delete cascade,
  plan_code               text not null references public.subscription_plans (code),
  status                  text not null default 'pending'
                            check (status in ('pending', 'active', 'grace', 'expired', 'cancelled')),
  started_at              timestamptz,
  current_period_end      timestamptz,
  grace_until             timestamptz,
  auto_renew              boolean not null default false,
  midtrans_subscription_id text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  unique (student_id, plan_code)
);

create index subscriptions_student_idx on public.subscriptions (student_id);
create index subscriptions_status_idx  on public.subscriptions (status);

create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

alter table public.subscriptions enable row level security;
create policy "langganan: siswa baca sendiri"
  on public.subscriptions for select using (student_id = auth.uid());
create policy "langganan: admin kelola"
  on public.subscriptions for all
  using (public.is_admin()) with check (public.is_admin());

-- ============ Soal + versi ============
create table public.questions (
  id           uuid primary key default gen_random_uuid(),
  subject_id   uuid not null references public.subjects (id) on delete restrict,
  topic_id     uuid references public.topics (id) on delete set null,
  jenjang      text not null references public.levels (code),
  type         text not null default 'pg' check (type in ('pg', 'isian')),
  status       text not null default 'draft'
                 check (status in ('draft', 'review', 'published', 'archived')),
  current_version int not null default 0,
  created_by   uuid references public.profiles (id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index questions_topic_idx   on public.questions (topic_id);
create index questions_status_idx  on public.questions (status);
create index questions_subject_idx on public.questions (subject_id);

create trigger questions_set_updated_at
  before update on public.questions
  for each row execute function public.set_updated_at();

-- Versi isi soal: mengedit membuat versi baru (riwayat tak rusak).
create table public.question_versions (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete cascade,
  version     int not null,
  body        text not null,
  options     jsonb,
  answer      text not null,
  explanation text,
  image_url   text,
  created_at  timestamptz not null default now(),
  unique (question_id, version)
);

create index question_versions_question_idx on public.question_versions (question_id);

alter table public.questions enable row level security;
alter table public.question_versions enable row level security;
create policy "questions: admin kelola"
  on public.questions for all
  using (public.is_admin()) with check (public.is_admin());
create policy "question_versions: admin kelola"
  on public.question_versions for all
  using (public.is_admin()) with check (public.is_admin());

-- ============ Percobaan ============
create table public.attempts (
  id               uuid primary key default gen_random_uuid(),
  student_id       uuid not null references public.students (id) on delete cascade,
  mode             text not null check (mode in ('latihan', 'tryout')),
  subject_id       uuid references public.subjects (id) on delete set null,
  topic_id         uuid references public.topics (id) on delete set null,
  jenjang          text references public.levels (code),
  total_questions  int not null default 0,
  correct_count    int not null default 0,
  started_at       timestamptz not null default now(),
  finished_at      timestamptz,
  duration_seconds int
);

create index attempts_student_idx on public.attempts (student_id);
create index attempts_topic_idx   on public.attempts (topic_id);

create table public.attempt_answers (
  id               uuid primary key default gen_random_uuid(),
  attempt_id       uuid not null references public.attempts (id) on delete cascade,
  question_id      uuid not null references public.questions (id) on delete cascade,
  question_version int not null,
  answer           text,
  is_correct       boolean,
  answered_at      timestamptz not null default now(),
  unique (attempt_id, question_id)
);

create index attempt_answers_attempt_idx on public.attempt_answers (attempt_id);

alter table public.attempts enable row level security;
alter table public.attempt_answers enable row level security;
create policy "attempts: siswa baca sendiri"
  on public.attempts for select using (student_id = auth.uid());
create policy "attempts: admin kelola"
  on public.attempts for all
  using (public.is_admin()) with check (public.is_admin());
create policy "attempt_answers: siswa baca sendiri"
  on public.attempt_answers for select
  using (exists (select 1 from public.attempts a
                 where a.id = attempt_answers.attempt_id and a.student_id = auth.uid()));
create policy "attempt_answers: admin kelola"
  on public.attempt_answers for all
  using (public.is_admin()) with check (public.is_admin());

-- ============ Statistik per topik ============
create table public.student_topic_stats (
  student_id      uuid not null references public.students (id) on delete cascade,
  topic_id        uuid not null references public.topics (id) on delete cascade,
  attempts_count  int not null default 0,
  correct_count   int not null default 0,
  accuracy        numeric(5, 2) not null default 0,
  last20_correct  int not null default 0,
  last20_total    int not null default 0,
  last_attempt_at timestamptz,
  trend           text check (trend in ('naik', 'turun', 'stabil')),
  updated_at      timestamptz not null default now(),
  primary key (student_id, topic_id)
);

alter table public.student_topic_stats enable row level security;
create policy "stats: siswa baca sendiri"
  on public.student_topic_stats for select using (student_id = auth.uid());
create policy "stats: admin kelola"
  on public.student_topic_stats for all
  using (public.is_admin()) with check (public.is_admin());

-- ============ Helper: langganan aktif? ============
create or replace function public.has_active_subscription(p_student uuid, p_plan text default 'bank_soal')
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.subscriptions
    where student_id = p_student
      and plan_code = p_plan
      and status in ('active', 'grace')
  );
$$;

revoke all on function public.has_active_subscription(uuid, text) from public, anon, authenticated;
grant execute on function public.has_active_subscription(uuid, text) to service_role;

-- ============ RPC: mulai latihan / tryout ============
-- Mengembalikan soal TANPA kunci jawaban & pembahasan.
create or replace function public.start_attempt(
  p_mode text,
  p_topic uuid default null,
  p_count int default 10,
  p_jenjang text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_attempt uuid;
  v_subject uuid;
  v_questions jsonb;
  v_count int;
begin
  if v_uid is null then
    raise exception 'Tidak terautentikasi' using errcode = '42501';
  end if;
  if p_mode not in ('latihan', 'tryout') then
    raise exception 'Mode tidak valid' using errcode = '22023';
  end if;
  if not public.has_active_subscription(v_uid) then
    raise exception 'Langganan tidak aktif' using errcode = '42501';
  end if;
  if p_topic is not null then
    select subject_id into v_subject from public.topics where id = p_topic;
  end if;

  select jsonb_agg(q) into v_questions from (
    select
      q.id, q.type, q.current_version as version,
      qv.body, qv.options, qv.image_url
    from public.questions q
    join public.question_versions qv
      on qv.question_id = q.id and qv.version = q.current_version
    where q.status = 'published'
      and (p_topic is null or q.topic_id = p_topic)
      and (p_jenjang is null or q.jenjang = p_jenjang)
    order by random()
    limit greatest(1, least(p_count, 50))
  ) q;

  v_count := coalesce(jsonb_array_length(v_questions), 0);
  if v_count = 0 then
    raise exception 'Belum ada soal untuk pilihan ini' using errcode = '22023';
  end if;

  insert into public.attempts (student_id, mode, subject_id, topic_id, jenjang, total_questions)
  values (v_uid, p_mode, v_subject, p_topic, p_jenjang, v_count)
  returning id into v_attempt;

  return jsonb_build_object('attempt_id', v_attempt, 'questions', v_questions);
end;
$$;

grant execute on function public.start_attempt(text, uuid, int, text) to authenticated;

-- ============ RPC: kumpulkan jawaban (penilaian di server) ============
create or replace function public.submit_attempt(
  p_attempt_id uuid,
  p_answers jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_attempt public.attempts;
  v_item jsonb;
  v_qid uuid;
  v_ans text;
  v_key text;
  v_expl text;
  v_correct boolean;
  v_correct_count int := 0;
  v_total int := 0;
  v_results jsonb := '[]'::jsonb;
  r record;
begin
  if v_uid is null then
    raise exception 'Tidak terautentikasi' using errcode = '42501';
  end if;

  select * into v_attempt from public.attempts
  where id = p_attempt_id and student_id = v_uid for update;
  if v_attempt.id is null then
    raise exception 'Percobaan tidak ditemukan' using errcode = '22023';
  end if;
  if v_attempt.finished_at is not null then
    raise exception 'Percobaan sudah selesai' using errcode = '22023';
  end if;

  for v_item in select * from jsonb_array_elements(p_answers)
  loop
    v_qid := (v_item ->> 'question_id')::uuid;
    v_ans := v_item ->> 'answer';

    select qv.answer, qv.explanation into v_key, v_expl
    from public.questions q
    join public.question_versions qv
      on qv.question_id = q.id and qv.version = q.current_version
    where q.id = v_qid;

    if v_key is null then
      continue;
    end if;

    v_correct := (v_ans is not null and upper(trim(v_ans)) = upper(trim(v_key)));
    if v_correct then
      v_correct_count := v_correct_count + 1;
    end if;
    v_total := v_total + 1;

    insert into public.attempt_answers
      (attempt_id, question_id, question_version, answer, is_correct)
    values
      (v_attempt.id, v_qid, (select current_version from public.questions where id = v_qid),
       v_ans, v_correct)
    on conflict (attempt_id, question_id)
    do update set answer = excluded.answer, is_correct = excluded.is_correct;

    v_results := v_results || jsonb_build_object(
      'question_id', v_qid,
      'is_correct', v_correct,
      'correct_answer', v_key,
      'explanation', v_expl
    );
  end loop;

  update public.attempts
     set correct_count = v_correct_count,
         finished_at = now(),
         duration_seconds = extract(epoch from (now() - started_at))::int
   where id = v_attempt.id;

  -- Perbarui statistik per topik (agar analisa langsung terbaru).
  for r in
    select q.topic_id,
           count(*) as n,
           count(*) filter (where aa.is_correct) as c
    from public.attempt_answers aa
    join public.questions q on q.id = aa.question_id
    where aa.attempt_id = v_attempt.id and q.topic_id is not null
    group by q.topic_id
  loop
    insert into public.student_topic_stats as st
      (student_id, topic_id, attempts_count, correct_count, accuracy, last_attempt_at, updated_at)
    values (v_uid, r.topic_id, r.n, r.c, round((r.c::numeric * 100) / nullif(r.n, 0), 2), now(), now())
    on conflict (student_id, topic_id) do update
      set attempts_count = st.attempts_count + r.n,
          correct_count  = st.correct_count + r.c,
          accuracy       = round(((st.correct_count + r.c)::numeric * 100)
                                 / nullif(st.attempts_count + r.n, 0), 2),
          last_attempt_at = now(),
          updated_at = now();

    -- Akurasi 20 jawaban terakhir + tren (naik/turun/stabil).
    update public.student_topic_stats st
       set last20_total = x.n,
           last20_correct = x.c,
           trend = case
             when x.n < 5 then null
             when (x.c::numeric / x.n) > (st.accuracy / 100 + 0.05) then 'naik'
             when (x.c::numeric / x.n) < (st.accuracy / 100 - 0.05) then 'turun'
             else 'stabil'
           end
      from (
        select count(*) as n, count(*) filter (where t.is_correct) as c
        from (
          select aa.is_correct
          from public.attempt_answers aa
          join public.attempts a on a.id = aa.attempt_id
          join public.questions q on q.id = aa.question_id
          where a.student_id = v_uid and q.topic_id = r.topic_id
          order by aa.answered_at desc
          limit 20
        ) t
      ) x
     where st.student_id = v_uid and st.topic_id = r.topic_id;
  end loop;

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'total', v_total,
    'correct', v_correct_count,
    'results', v_results
  );
end;
$$;

grant execute on function public.submit_attempt(uuid, jsonb) to authenticated;

-- ============ Cron: status langganan (active -> grace -> expired) ============
create or replace function public.refresh_subscription_statuses()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  v_n int;
begin
  update public.subscriptions set status = 'grace'
   where status = 'active' and current_period_end <= now() and grace_until > now();
  get diagnostics v_n = row_count; v_count := v_count + v_n;

  update public.subscriptions set status = 'expired'
   where status in ('active', 'grace') and grace_until <= now();
  get diagnostics v_n = row_count; v_count := v_count + v_n;

  return v_count;
end;
$$;

revoke all on function public.refresh_subscription_statuses() from public, anon, authenticated;

select cron.schedule('refresh-subscriptions', '*/10 * * * *',
  $$select public.refresh_subscription_statuses();$$);
