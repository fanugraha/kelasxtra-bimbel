-- View untuk CMS soal: soal + versi terkini + nama mapel/topik.
-- security_invoker = true -> RLS tabel berlaku: admin lihat semua, siswa 0 baris
-- (view ini memuat KUNCI JAWABAN, jadi tak boleh terbaca siswa).

create or replace view public.questions_admin
with (security_invoker = true)
as
select
  q.id, q.subject_id, q.topic_id, q.jenjang, q.type, q.status,
  q.current_version, q.updated_at,
  qv.body, qv.options, qv.answer, qv.explanation, qv.image_url,
  s.name as subject_name, t.name as topic_name
from public.questions q
left join public.question_versions qv
  on qv.question_id = q.id and qv.version = q.current_version
left join public.subjects s on s.id = q.subject_id
left join public.topics t on t.id = q.topic_id;

grant select on public.questions_admin to authenticated;
