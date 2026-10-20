-- Perbaikan temuan pentest (Strix):
-- 1) signup publik tidak boleh menentukan role/admin_role;
-- 2) user tidak boleh mengubah role/admin_role sendiri;
-- 3) tutor tidak boleh mengubah status, rating, atau data payout sendiri;
-- 4) cabut akses anon/PUBLIC ke RPC sensitif;
-- 5) kunci search_path fungsi guard yang tersisa.
--
-- Catatan: admin yang sudah terlanjur dibuat lewat metadata tidak diubah otomatis.
-- Audit manual diperlukan sebelum menurunkan akun.

-- 1) Profil baru selalu siswa. Tutor/admin dibuat lewat alur server resmi.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, admin_role, full_name, email, phone)
  values (
    new.id,
    'student',
    null,
    new.raw_user_meta_data ->> 'full_name',
    new.email,
    new.raw_user_meta_data ->> 'phone'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- 2) Kunci role & admin_role saat user mengubah profilnya sendiri.
create or replace function public.guard_profile_self_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id and not public.is_admin() then
    new.role := old.role;
    new.admin_role := old.admin_role;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_self_update on public.profiles;
create trigger profiles_guard_self_update
  before update on public.profiles
  for each row execute function public.guard_profile_self_update();

-- 3) Tutor hanya boleh mengubah data dirinya yang non-sensitif.
create or replace function public.guard_tutor_self_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id and not public.is_admin() then
    new.status := old.status;
    new.rating_avg := old.rating_avg;
    new.bank_name := old.bank_name;
    new.bank_account_number := old.bank_account_number;
    new.bank_account_holder := old.bank_account_holder;
    new.invite_token := old.invite_token;
    new.invite_expires_at := old.invite_expires_at;
    new.invited_at := old.invited_at;
    new.activated_at := old.activated_at;
    new.suspended_at := old.suspended_at;
    new.suspend_reason := old.suspend_reason;
  end if;
  return new;
end;
$$;

drop trigger if exists tutors_guard_self_update on public.tutors;
create trigger tutors_guard_self_update
  before update on public.tutors
  for each row execute function public.guard_tutor_self_update();

-- 4) RPC sensitif: cabut grant bawaan PUBLIC, beri hanya ke user login + service role.
revoke execute on function public.cancel_group_seat_with_credit(uuid, text) from public, anon;
revoke execute on function public.cancel_package_with_credit(uuid, text) from public, anon;
revoke execute on function public.cancel_reschedule_request(uuid) from public, anon;
revoke execute on function public.grant_student_credit(uuid, integer, text, text) from public, anon;
revoke execute on function public.request_reschedule(uuid, timestamptz, text) from public, anon;
revoke execute on function public.reschedule_no_show(uuid, timestamptz, text) from public, anon;
revoke execute on function public.resolve_complaint(uuid, text, text, integer) from public, anon;
revoke execute on function public.respond_reschedule(uuid, boolean, text) from public, anon;
revoke execute on function public.set_package_price(text, integer, text, integer, integer) from public, anon;

grant execute on function public.cancel_group_seat_with_credit(uuid, text) to authenticated, service_role;
grant execute on function public.cancel_package_with_credit(uuid, text) to authenticated, service_role;
grant execute on function public.cancel_reschedule_request(uuid) to authenticated, service_role;
grant execute on function public.grant_student_credit(uuid, integer, text, text) to authenticated, service_role;
grant execute on function public.request_reschedule(uuid, timestamptz, text) to authenticated, service_role;
grant execute on function public.reschedule_no_show(uuid, timestamptz, text) to authenticated, service_role;
grant execute on function public.resolve_complaint(uuid, text, text, integer) to authenticated, service_role;
grant execute on function public.respond_reschedule(uuid, boolean, text) to authenticated, service_role;
grant execute on function public.set_package_price(text, integer, text, integer, integer) to authenticated, service_role;

-- 5) search_path tetap.
alter function public.booking_slot_range(timestamptz, integer) set search_path = public;
alter function public.guard_meeting_url() set search_path = public;
alter function public.is_zoom_url(text) set search_path = public;
