-- Fase 6 — View absensi kelas grup untuk tutor (nama siswa + status kehadiran).
-- Tutor tidak punya akses langsung ke `group_classes`/`group_seats`/`students`
-- (RLS khusus admin), jadi disediakan view definer yang difilter tutor_id = auth.uid().
-- Catatan: linter `security_definer_view` menandai ini; disengaja & kolom terbatas.

create or replace view public.group_attendance_visible as
select
  gs.id            as group_session_id,
  gc.id            as group_class_id,
  gs.seq,
  gs.scheduled_at,
  gc.jenjang,
  gc.mode,
  gc.status        as class_status,
  sub.name         as subject_name,
  s.student_id,
  st.full_name     as student_name,
  ga.status        as attendance_status
from public.group_sessions gs
join public.group_classes gc on gc.id = gs.group_class_id
join public.subjects sub on sub.id = gc.subject_id
join public.group_seats s on s.group_class_id = gc.id and s.status = 'active'
join public.students st on st.id = s.student_id
left join public.group_attendance ga
  on ga.group_session_id = gs.id and ga.student_id = s.student_id
where gc.tutor_id = auth.uid() or public.is_admin();

grant select on public.group_attendance_visible to authenticated;
