-- Perbaikan RLS Fase 6: policy tidak boleh subquery ke `bookings` karena SELECT tabel
-- itu sudah dicabut dari client (migrasi 00013). Pakai helper security definer.

create or replace function public.booking_is_student(p_booking uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.bookings b
    where b.id = p_booking and b.student_id = auth.uid()
  );
$$;
revoke all on function public.booking_is_student(uuid) from public;
grant execute on function public.booking_is_student(uuid) to authenticated;

create or replace function public.thread_participant(p_thread uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.booking_threads t
    join public.bookings b on b.id = t.booking_id
    where t.id = p_thread
      and (b.student_id = auth.uid() or b.tutor_id = auth.uid())
  );
$$;
revoke all on function public.thread_participant(uuid) from public;
grant execute on function public.thread_participant(uuid) to authenticated;

drop policy if exists "reschedules: peserta baca" on public.booking_reschedules;
create policy "reschedules: peserta baca"
  on public.booking_reschedules for select
  using (public.booking_participant(booking_id) or public.is_admin());

drop policy if exists "notes: siswa baca" on public.session_notes;
create policy "notes: siswa baca"
  on public.session_notes for select
  using (public.booking_is_student(booking_id));

drop policy if exists "complaints: peserta baca" on public.complaints;
create policy "complaints: peserta baca"
  on public.complaints for select
  using (opened_by = auth.uid()
         or public.booking_participant(booking_id)
         or public.is_admin());

drop policy if exists "threads: peserta baca" on public.booking_threads;
create policy "threads: peserta baca"
  on public.booking_threads for select
  using (public.booking_participant(booking_id) or public.is_admin());

drop policy if exists "messages: peserta baca" on public.thread_messages;
create policy "messages: peserta baca"
  on public.thread_messages for select
  using (public.thread_participant(thread_id) or public.is_admin());
