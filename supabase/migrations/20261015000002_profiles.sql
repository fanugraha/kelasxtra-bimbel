-- Fase 0 — profiles (akun inti, 1:1 dengan auth.users)
-- role: student | tutor | admin
-- admin_role: verifikator | finance | konten | cs (hanya bila role = admin)

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  role        text not null default 'student'
                check (role in ('student', 'tutor', 'admin')),
  admin_role  text
                check (admin_role in ('verifikator', 'finance', 'konten', 'cs')),
  full_name   text,
  email       text,
  phone       text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index profiles_role_idx on public.profiles (role);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Helper: apakah pengguna saat ini admin
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- Helper: apakah pengguna saat ini admin dengan peran tertentu
create or replace function public.is_admin_role(p_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and admin_role = p_role
  );
$$;

-- Auto-buat profil saat user baru dibuat di auth.users.
-- role & admin_role boleh dibawa dari user metadata saat pembuatan akun oleh admin.
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
    coalesce(new.raw_user_meta_data ->> 'role', 'student'),
    new.raw_user_meta_data ->> 'admin_role',
    new.raw_user_meta_data ->> 'full_name',
    new.email,
    new.raw_user_meta_data ->> 'phone'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS: tolak semua secara default
alter table public.profiles enable row level security;

create policy "profiles: baca sendiri"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin());

create policy "profiles: ubah sendiri"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));

create policy "profiles: admin kelola semua"
  on public.profiles for all
  using (public.is_admin())
  with check (public.is_admin());

-- Insert dari client tidak diizinkan; profil dibuat oleh trigger (security definer).
