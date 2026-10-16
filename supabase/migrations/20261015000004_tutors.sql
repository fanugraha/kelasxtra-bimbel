-- Fase 0 — tutors (profil tutor, 1:1 dengan profiles.role = 'tutor')
-- Tutor direkrut internal: admin buat akun -> link undangan (exp 7 hari) -> tutor aktivasi.
-- Tidak ada pendaftaran mandiri, tidak ada upload KTP di aplikasi (rekrutmen offline).
-- status: diundang | aktif | suspend

create table public.tutors (
  id                    uuid primary key references public.profiles (id) on delete cascade,
  status                text not null default 'diundang'
                          check (status in ('diundang', 'aktif', 'suspend')),
  full_name             text not null,
  bio                   text,
  education             text,
  photo_url             text,
  rating_avg            numeric(3, 2) not null default 0,
  -- undangan aktivasi (dipakai Fase 1)
  invite_token          text unique,
  invite_expires_at     timestamptz,
  invited_at            timestamptz,
  activated_at          timestamptz,
  suspended_at          timestamptz,
  suspend_reason        text,
  -- data bank untuk payroll bulanan (Fase 7)
  bank_name             text,
  bank_account_number   text,
  bank_account_holder   text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index tutors_status_idx on public.tutors (status);

create trigger tutors_set_updated_at
  before update on public.tutors
  for each row execute function public.set_updated_at();

alter table public.tutors enable row level security;

-- Katalog publik: siapa pun boleh lihat tutor aktif (kolom sensitif jangan diekspos lewat view, lihat catatan)
create policy "tutors: baca tutor aktif"
  on public.tutors for select
  using (status = 'aktif');

-- Tutor baca & ubah datanya sendiri (termasuk saat masih 'diundang' untuk aktivasi)
create policy "tutors: baca sendiri"
  on public.tutors for select
  using (id = auth.uid() or public.is_admin());

create policy "tutors: ubah sendiri"
  on public.tutors for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "tutors: admin kelola semua"
  on public.tutors for all
  using (public.is_admin())
  with check (public.is_admin());

-- CATATAN: policy "baca tutor aktif" membuka seluruh kolom (termasuk bank).
-- Sebelum katalog dipakai (Fase 2), buat VIEW publik tanpa kolom bank + cabut policy ini.
