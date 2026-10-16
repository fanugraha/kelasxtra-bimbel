-- Fase 0 — master data: jenjang, mapel, topik, price matrix
-- Harga = data (bukan hardcode). Integer rupiah. Snapshot ke transaksi saat checkout.

create table public.levels (
  code       text primary key check (code in ('SD', 'SMP', 'SMA')),
  name       text not null,
  sort_order int  not null default 0
);

create table public.subjects (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  slug       text not null unique,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.topics (
  id         uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects (id) on delete cascade,
  jenjang    text references public.levels (code),
  name       text not null,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

create index topics_subject_idx on public.topics (subject_id);

-- price_matrix: jenjang x durasi x mode x tipe layanan
-- mode: online | offline ; type: privat | grup
create table public.price_matrix (
  id               uuid primary key default gen_random_uuid(),
  jenjang          text not null references public.levels (code),
  duration_minutes int  not null check (duration_minutes in (60, 90, 120)),
  mode             text not null check (mode in ('online', 'offline')),
  type             text not null check (type in ('privat', 'grup')),
  price            integer not null check (price >= 0),
  effective_from   timestamptz not null default now(),
  active           boolean not null default true,
  created_at       timestamptz not null default now()
);

-- Satu harga aktif per kombinasi
create unique index price_matrix_unique_active
  on public.price_matrix (jenjang, duration_minutes, mode, type)
  where active;

alter table public.levels       enable row level security;
alter table public.subjects     enable row level security;
alter table public.topics       enable row level security;
alter table public.price_matrix enable row level security;

-- Master data katalog: boleh dibaca publik (anon + authenticated)
create policy "levels: baca publik"   on public.levels       for select using (true);
create policy "subjects: baca publik" on public.subjects     for select using (active);
create policy "topics: baca publik"   on public.topics       for select using (active);
create policy "price_matrix: baca publik aktif"
  on public.price_matrix for select using (active);

-- Hanya admin yang boleh mengubah master data
create policy "levels: admin kelola"       on public.levels       for all using (public.is_admin()) with check (public.is_admin());
create policy "subjects: admin kelola"     on public.subjects     for all using (public.is_admin()) with check (public.is_admin());
create policy "topics: admin kelola"       on public.topics       for all using (public.is_admin()) with check (public.is_admin());
create policy "price_matrix: admin kelola" on public.price_matrix for all using (public.is_admin()) with check (public.is_admin());
