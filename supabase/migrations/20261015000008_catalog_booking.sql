-- Fase 2 — Katalog & Booking Privat + Pembayaran
-- Tabel: tutor_subjects, tutor_availability, vouchers, voucher_redemptions, bookings, payments
-- Aturan uang: integer rupiah; tutor_share = floor(price*75/100); snapshot harga ke booking.

-- Mapping tutor -> mapel + jenjang (untuk filter katalog)
create table public.tutor_subjects (
  tutor_id   uuid not null references public.tutors (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  jenjang    text not null references public.levels (code),
  primary key (tutor_id, subject_id, jenjang)
);

-- Ketersediaan mingguan tutor (template; booking memilih datetime konkret di dalamnya)
create table public.tutor_availability (
  id          uuid primary key default gen_random_uuid(),
  tutor_id    uuid not null references public.tutors (id) on delete cascade,
  day_of_week int not null check (day_of_week between 0 and 6), -- 0=Minggu
  start_time  time not null,
  end_time    time not null,
  mode        text not null check (mode in ('online', 'offline')),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  check (end_time > start_time)
);

create index tutor_availability_tutor_idx on public.tutor_availability (tutor_id);

-- Voucher/promo
create table public.vouchers (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  discount_type  text not null check (discount_type in ('percent', 'nominal')),
  discount_value integer not null check (discount_value >= 0),
  min_purchase   integer not null default 0,
  quota          integer check (quota is null or quota >= 0), -- null = tak terbatas
  used           integer not null default 0,
  per_student_limit integer not null default 1,
  active         boolean not null default true,
  starts_at      timestamptz,
  expires_at     timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (quota is null or used <= quota)
);

create trigger vouchers_set_updated_at
  before update on public.vouchers
  for each row execute function public.set_updated_at();

-- Pemakaian voucher per siswa (race-safe: kuota dikunci saat bayar dimulai)
create table public.voucher_redemptions (
  id         uuid primary key default gen_random_uuid(),
  voucher_id uuid not null references public.vouchers (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  status     text not null default 'locked' check (status in ('locked', 'used', 'released')),
  created_at timestamptz not null default now()
);

create index voucher_redemptions_voucher_idx on public.voucher_redemptions (voucher_id);
create index voucher_redemptions_student_idx on public.voucher_redemptions (student_id);

-- Booking = satu sesi privat
-- status (11): pending_payment, confirmed, in_progress, completed, cancelled,
--              expired, no_show_tutor, no_show_student, disputed, refunded, rescheduled
create table public.bookings (
  id                  uuid primary key default gen_random_uuid(),
  student_id          uuid not null references public.students (id) on delete cascade,
  tutor_id            uuid not null references public.tutors (id) on delete restrict,
  subject_id          uuid not null references public.subjects (id) on delete restrict,
  jenjang             text not null references public.levels (code),
  duration_minutes    int not null check (duration_minutes in (60, 90, 120)),
  mode                text not null check (mode in ('online', 'offline')),
  type                text not null default 'privat' check (type in ('privat', 'grup')),
  scheduled_at        timestamptz not null,
  -- snapshot harga normal (integer rupiah). tutor_share SELALU dari harga normal.
  price               integer not null check (price >= 0),
  discount            integer not null default 0 check (discount >= 0),
  amount_due          integer generated always as (price - discount) stored,
  tutor_share         integer generated always as ((price * 75) / 100) stored,
  platform_share      integer generated always as (price - (price * 75) / 100) stored,
  status              text not null default 'pending_payment' check (status in (
                        'pending_payment', 'confirmed', 'in_progress', 'completed',
                        'cancelled', 'expired', 'no_show_tutor', 'no_show_student',
                        'disputed', 'refunded', 'rescheduled')),
  voucher_id          uuid references public.vouchers (id) on delete set null,
  -- Fase 3: FK ditambahkan saat tabel package_purchases dibuat
  package_purchase_id uuid,
  -- alamat lengkap (offline). HANYA dibuka pasca-bayar.
  address             text,
  lock_expires_at     timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (discount <= price)
);

create index bookings_student_idx on public.bookings (student_id);
create index bookings_tutor_idx   on public.bookings (tutor_id);
create index bookings_status_idx  on public.bookings (status);
create index bookings_scheduled_idx on public.bookings (scheduled_at);

create trigger bookings_set_updated_at
  before update on public.bookings
  for each row execute function public.set_updated_at();

-- Payments = transaksi Midtrans. Idempoten by order_id.
create table public.payments (
  id          uuid primary key default gen_random_uuid(),
  order_id    text not null unique,
  type        text not null check (type in ('booking', 'package', 'group_seat', 'subscription')),
  booking_id  uuid references public.bookings (id) on delete set null,
  amount      integer not null check (amount >= 0),
  gateway_fee integer not null default 0,
  voucher_id  uuid references public.vouchers (id) on delete set null,
  status      text not null default 'pending' check (status in (
                'pending', 'settlement', 'capture', 'deny', 'cancel',
                'expire', 'refund', 'partial_refund')),
  paid_at     timestamptz,
  raw         jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index payments_booking_idx on public.payments (booking_id);
create index payments_status_idx  on public.payments (status);

create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

-- ============ RLS (deny-by-default) ============
alter table public.tutor_subjects       enable row level security;
alter table public.tutor_availability   enable row level security;
alter table public.vouchers             enable row level security;
alter table public.voucher_redemptions  enable row level security;
alter table public.bookings             enable row level security;
alter table public.payments             enable row level security;

-- tutor_subjects: publik (katalog), tutor kelola sendiri, admin kelola
create policy "tutor_subjects: baca publik"
  on public.tutor_subjects for select using (true);
create policy "tutor_subjects: tutor kelola sendiri"
  on public.tutor_subjects for all
  using (tutor_id = auth.uid()) with check (tutor_id = auth.uid());
create policy "tutor_subjects: admin kelola"
  on public.tutor_subjects for all
  using (public.is_admin()) with check (public.is_admin());

-- tutor_availability: slot aktif publik, tutor kelola sendiri, admin kelola
create policy "tutor_availability: baca publik aktif"
  on public.tutor_availability for select using (active);
create policy "tutor_availability: tutor kelola sendiri"
  on public.tutor_availability for all
  using (tutor_id = auth.uid()) with check (tutor_id = auth.uid());
create policy "tutor_availability: admin kelola"
  on public.tutor_availability for all
  using (public.is_admin()) with check (public.is_admin());

-- vouchers: hanya admin (validasi dari server/Edge Function, bukan client)
create policy "vouchers: admin kelola"
  on public.vouchers for all
  using (public.is_admin()) with check (public.is_admin());

-- voucher_redemptions: siswa lihat miliknya; admin kelola; insert via service role
create policy "voucher_redemptions: siswa baca sendiri"
  on public.voucher_redemptions for select using (student_id = auth.uid());
create policy "voucher_redemptions: admin kelola"
  on public.voucher_redemptions for all
  using (public.is_admin()) with check (public.is_admin());

-- bookings: siswa lihat miliknya, tutor lihat miliknya, admin semua.
-- Insert/ubah lewat Edge Function (service role) agar harga & status tak bisa dipalsukan.
create policy "bookings: siswa baca sendiri"
  on public.bookings for select using (student_id = auth.uid());
create policy "bookings: tutor baca sendiri"
  on public.bookings for select using (tutor_id = auth.uid());
create policy "bookings: admin kelola"
  on public.bookings for all
  using (public.is_admin()) with check (public.is_admin());

-- payments: siswa lihat lewat bookingnya, tutor lihat lewat bookingnya, admin semua.
create policy "payments: siswa baca sendiri"
  on public.payments for select
  using (exists (
    select 1 from public.bookings b
    where b.id = payments.booking_id and b.student_id = auth.uid()
  ));
create policy "payments: tutor baca sendiri"
  on public.payments for select
  using (exists (
    select 1 from public.bookings b
    where b.id = payments.booking_id and b.tutor_id = auth.uid()
  ));
create policy "payments: admin kelola"
  on public.payments for all
  using (public.is_admin()) with check (public.is_admin());
