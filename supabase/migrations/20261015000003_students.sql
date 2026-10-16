-- Fase 0 — students (profil siswa, 1:1 dengan profiles.role = 'student')
-- Aturan #18: satu akun = satu siswa, tanpa entitas wali terpisah.
-- Registrasi <18 tahun wajib pernyataan izin mandiri + timestamp + kontak darurat.

create table public.students (
  id                       uuid primary key references public.profiles (id) on delete cascade,
  jenjang                  text not null check (jenjang in ('SD', 'SMP', 'SMA')),
  full_name                text not null,
  school                   text,
  birth_date               date,
  emergency_contact_name   text not null,
  emergency_contact_phone  text not null,
  guardian_consent         boolean not null default false,
  guardian_consent_at      timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

create trigger students_set_updated_at
  before update on public.students
  for each row execute function public.set_updated_at();

alter table public.students enable row level security;

-- Siswa baca/ubah datanya sendiri
create policy "students: baca sendiri"
  on public.students for select
  using (id = auth.uid() or public.is_admin());

create policy "students: ubah sendiri"
  on public.students for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "students: buat sendiri"
  on public.students for insert
  with check (id = auth.uid());

create policy "students: admin kelola semua"
  on public.students for all
  using (public.is_admin())
  with check (public.is_admin());
