-- Perbaikan RLS: policy `payments` memakai subquery ke `bookings` yang SELECT-nya
-- sudah dicabut dari client (migrasi 00013) → 403 walau admin. Pakai helper definer.

create or replace function public.booking_has_student(p_booking uuid, p_student uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.bookings b
    where b.id = p_booking and b.student_id = p_student
  );
$$;
revoke all on function public.booking_has_student(uuid, uuid) from public;
grant execute on function public.booking_has_student(uuid, uuid) to authenticated;

create or replace function public.booking_has_tutor(p_booking uuid, p_tutor uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.bookings b
    where b.id = p_booking and b.tutor_id = p_tutor
  );
$$;
revoke all on function public.booking_has_tutor(uuid, uuid) from public;
grant execute on function public.booking_has_tutor(uuid, uuid) to authenticated;

drop policy if exists "payments: siswa baca sendiri" on public.payments;
create policy "payments: siswa baca sendiri"
  on public.payments for select
  using (public.booking_has_student(booking_id, auth.uid()));

drop policy if exists "payments: tutor baca sendiri" on public.payments;
create policy "payments: tutor baca sendiri"
  on public.payments for select
  using (public.booking_has_tutor(booking_id, auth.uid()));
