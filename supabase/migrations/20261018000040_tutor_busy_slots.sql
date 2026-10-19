-- Fase 12 — Slot sibuk untuk penyaringan jadwal di wizard beli paket.
-- Mengembalikan interval sibuk (tutor: semua siswanya; student: milik pemanggil)
-- tanpa membocorkan identitas. Dipakai client agar jam/tanggal yang sudah
-- terisi tidak ditampilkan sebagai pilihan. Server tetap memvalidasi ulang
-- lewat `reserve_package_schedule` (sumber kebenaran).
--
-- Status yang dianggap mengunci slot sama dengan reserve_package_schedule:
-- semua kecuali cancelled/expired/refunded.

create or replace function public.tutor_busy_slots(p_tutor_id uuid)
returns table (busy_start timestamptz, busy_end timestamptz)
language sql
security definer
set search_path = public
as $$
  select b.scheduled_at,
         b.scheduled_at + make_interval(mins => b.duration_minutes)
  from public.bookings b
  where b.tutor_id = p_tutor_id
    and b.status not in ('cancelled', 'expired', 'refunded')
    and b.scheduled_at > now()
    and b.scheduled_at < now() + interval '5 months'
  union
  select b.scheduled_at,
         b.scheduled_at + make_interval(mins => b.duration_minutes)
  from public.bookings b
  where b.student_id = auth.uid()
    and b.status not in ('cancelled', 'expired', 'refunded')
    and b.scheduled_at > now()
    and b.scheduled_at < now() + interval '5 months';
$$;

revoke all on function public.tutor_busy_slots(uuid) from public, anon;
grant execute on function public.tutor_busy_slots(uuid) to authenticated;
