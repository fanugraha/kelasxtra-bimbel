-- admin_role juga tidak boleh diubah lewat self-update, termasuk oleh admin.
-- Perubahan peran admin untuk pengguna lain tetap lewat policy admin.
create or replace function public.guard_profile_self_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id then
    new.role := old.role;
    new.admin_role := old.admin_role;
  end if;
  return new;
end;
$$;
