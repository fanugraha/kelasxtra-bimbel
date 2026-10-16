-- Seed Fase 0 — master data.
-- Aman dijalankan berulang (idempoten).
-- HARGA DI BAWAH ADALAH PLACEHOLDER — management menetapkan angka final lewat dashboard.
-- Catatan: mode online sengaja lebih murah Rp10.000 dari offline (lihat PRD risiko kapasitas rumah).

-- Jenjang
insert into public.levels (code, name, sort_order) values
  ('SD',  'SD',  1),
  ('SMP', 'SMP', 2),
  ('SMA', 'SMA', 3)
on conflict (code) do update set name = excluded.name, sort_order = excluded.sort_order;

-- Mapel
insert into public.subjects (name, slug) values
  ('Matematika',    'matematika'),
  ('Fisika',        'fisika'),
  ('Kimia',         'kimia'),
  ('Biologi',       'biologi'),
  ('Bahasa Inggris','bahasa-inggris'),
  ('Bahasa Indonesia','bahasa-indonesia'),
  ('Ekonomi',       'ekonomi')
on conflict (slug) do update set name = excluded.name;

-- Topik contoh (per mapel, jenjang)
insert into public.topics (subject_id, jenjang, name)
select s.id, v.jenjang, v.name
from public.subjects s
join (values
  ('matematika', 'SMP', 'Aljabar'),
  ('matematika', 'SMP', 'Geometri'),
  ('matematika', 'SMA', 'Trigonometri'),
  ('matematika', 'SMA', 'Kalkulus Dasar'),
  ('fisika',     'SMA', 'Kinematika'),
  ('fisika',     'SMA', 'Dinamika'),
  ('kimia',      'SMA', 'Stoikiometri'),
  ('biologi',    'SMA', 'Genetika'),
  ('bahasa-inggris', 'SMP', 'Tenses'),
  ('bahasa-indonesia', 'SMP', 'Teks Eksposisi')
) as v(slug, jenjang, name) on s.slug = v.slug
where not exists (
  select 1 from public.topics t
  where t.subject_id = s.id and t.jenjang = v.jenjang and t.name = v.name
);

-- Price matrix (placeholder)
insert into public.price_matrix (jenjang, duration_minutes, mode, type, price) values
  ('SD',  60,  'online',  'privat',  60000),
  ('SD',  90,  'online',  'privat',  85000),
  ('SD',  120, 'online',  'privat', 110000),
  ('SD',  60,  'offline', 'privat',  70000),
  ('SD',  90,  'offline', 'privat',  95000),
  ('SD',  120, 'offline', 'privat', 120000),
  ('SMP', 60,  'online',  'privat',  75000),
  ('SMP', 90,  'online',  'privat', 105000),
  ('SMP', 120, 'online',  'privat', 135000),
  ('SMP', 60,  'offline', 'privat',  85000),
  ('SMP', 90,  'offline', 'privat', 115000),
  ('SMP', 120, 'offline', 'privat', 145000),
  ('SMA', 60,  'online',  'privat',  85000),
  ('SMA', 90,  'online',  'privat', 120000),
  ('SMA', 120, 'online',  'privat', 155000),
  ('SMA', 60,  'offline', 'privat',  95000),
  ('SMA', 90,  'offline', 'privat', 130000),
  ('SMA', 120, 'offline', 'privat', 165000),
  ('SD',  90,  'online',  'grup',    45000),
  ('SD',  90,  'offline', 'grup',    55000),
  ('SMP', 90,  'online',  'grup',    55000),
  ('SMP', 90,  'offline', 'grup',    65000),
  ('SMA', 90,  'online',  'grup',    65000),
  ('SMA', 90,  'offline', 'grup',    75000)
on conflict (jenjang, duration_minutes, mode, type) where active
do update set price = excluded.price;
