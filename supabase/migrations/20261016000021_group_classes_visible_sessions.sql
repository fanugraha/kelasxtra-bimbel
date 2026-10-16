-- Tambah ringkasan jadwal ke view kelas grup (hindari query N+1 di mobile).

create or replace view public.group_classes_visible as
select
  g.id, g.tutor_id, g.subject_id, g.jenjang, g.mode, g.duration_minutes,
  g.total_sesi, g.discount_percent, g.price_per_session, g.price_total,
  g.min_seats, g.max_seats, g.seats_taken, g.status, g.min_confirm_deadline,
  g.created_at, t.full_name as tutor_name, s.name as subject_name,
  (select min(gs.scheduled_at) from public.group_sessions gs where gs.group_class_id = g.id) as first_session,
  (select max(gs.scheduled_at) from public.group_sessions gs where gs.group_class_id = g.id) as last_session
from public.group_classes g
join public.tutors t on t.id = g.tutor_id
join public.subjects s on s.id = g.subject_id
where g.status in ('open', 'confirmed');

grant select on public.group_classes_visible to authenticated;
