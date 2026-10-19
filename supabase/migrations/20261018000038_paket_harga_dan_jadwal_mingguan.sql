-- Model bisnis paket (keputusan pemilik 18 Okt 2026):
--   * Siswa hanya membeli PAKET (4/8/12 pertemuan, seminggu sekali) — tidak ada
--     pembelian per sesi dari aplikasi siswa.
--   * Harga paket DITETAPKAN ADMIN di `package_prices` (bukan hitungan diskon).
--   * Siswa memilih hari + jam saat membeli; semua pertemuan mingguan dibuat
--     otomatis dan ditahan 30 menit sampai pembayaran lunas.
--   * Masa berlaku mengikuti jumlah pertemuan: 4 = 1 bulan, 8 = 2 bulan, 12 = 3 bulan
--     (diperpanjang otomatis bila pertemuan terakhir jatuh lewat dari itu).
--   * Bagi hasil tutor tetap 75% dari harga sesi normal (tutor_share otomatis
--     dari kolom `price` booking).

-- ============ 1. Harga paket (dikelola admin) ============
create table public.package_prices (
  id               uuid primary key default gen_random_uuid(),
  jenjang          text not null references public.levels (code),
  duration_minutes int  not null check (duration_minutes in (60, 90, 120)),
  mode             text not null check (mode in ('online', 'offline')),
  total_sesi       int  not null check (total_sesi in (4, 8, 12)),
  price            integer not null check (price >= 0),
  effective_from   timestamptz not null default now(),
  active           boolean not null default true,
  created_at       timestamptz not null default now()
);

-- Satu harga aktif per kombinasi (harga lama disimpan sebagai riwayat).
create unique index package_prices_unique_active
  on public.package_prices (jenjang, duration_minutes, mode, total_sesi)
  where active;

alter table public.package_prices enable row level security;

create policy "package_prices: baca publik aktif"
  on public.package_prices for select using (active);
create policy "package_prices: admin kelola"
  on public.package_prices for all
  using (public.is_admin()) with check (public.is_admin());

-- ============ 2. Jadwal mingguan pada paket ============
alter table public.package_purchases
  add column if not exists schedule_day        int check (schedule_day between 0 and 6),
  add column if not exists schedule_start_time time,
  add column if not exists schedule_start_date date,
  add column if not exists address             text;

-- Cegah sesi dobel bila aktivasi dipanggil lebih dari sekali.
create unique index if not exists bookings_package_slot_unique
  on public.bookings (package_purchase_id, scheduled_at)
  where package_purchase_id is not null;

-- ============ 3. Admin: set harga paket ============
create or replace function public.set_package_price(
  p_jenjang          text,
  p_duration_minutes int,
  p_mode             text,
  p_total_sesi       int,
  p_price            integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old    public.package_prices;
  v_new_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_total_sesi not in (4, 8, 12) then
    raise exception 'Jumlah pertemuan harus 4, 8, atau 12' using errcode = '22023';
  end if;
  if p_price < 0 then
    raise exception 'Harga tidak boleh negatif' using errcode = '22023';
  end if;

  select * into v_old
  from public.package_prices
  where jenjang = p_jenjang
    and duration_minutes = p_duration_minutes
    and mode = p_mode
    and total_sesi = p_total_sesi
    and active
  limit 1;

  update public.package_prices
     set active = false
   where jenjang = p_jenjang
     and duration_minutes = p_duration_minutes
     and mode = p_mode
     and total_sesi = p_total_sesi
     and active;

  insert into public.package_prices (jenjang, duration_minutes, mode, total_sesi, price)
  values (p_jenjang, p_duration_minutes, p_mode, p_total_sesi, p_price)
  returning id into v_new_id;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (
    auth.uid(), 'package_prices.update', 'package_prices', v_new_id::text,
    case when v_old.id is null then null
         else jsonb_build_object('price', v_old.price) end,
    jsonb_build_object('jenjang', p_jenjang, 'duration_minutes', p_duration_minutes,
                       'mode', p_mode, 'total_sesi', p_total_sesi, 'price', p_price)
  );

  return v_new_id;
end;
$$;

grant execute on function public.set_package_price(text, int, text, int, integer) to authenticated;

-- ============ 4. Tahan jadwal paket (dipanggil saat Snap dibuat) ============
-- Membuat SEMUA pertemuan mingguan sebagai booking 'pending_payment' yang
-- menahan slot 30 menit. Gagal = slot atau jadwal tidak valid.
create or replace function public.reserve_package_schedule(p_package_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v        public.package_purchases;
  v_local  timestamp;
  v_dt     timestamptz;
  v_made   integer := 0;
  i        integer;
begin
  select * into v from public.package_purchases where id = p_package_id for update;
  if v.id is null then
    raise exception 'Paket tidak ditemukan' using errcode = '22023';
  end if;
  if v.status <> 'pending_payment' then
    raise exception 'Paket tidak sedang menunggu pembayaran' using errcode = '22023';
  end if;
  if v.schedule_start_date is null or v.schedule_start_time is null or v.schedule_day is null then
    raise exception 'Jadwal paket belum dipilih' using errcode = '22023';
  end if;
  if v.mode = 'offline' and (v.address is null or btrim(v.address) = '') then
    raise exception 'Alamat belajar wajib untuk paket offline' using errcode = '22023';
  end if;

  -- Serialisasi per tutor: cegah dua siswa menahan slot yang sama sekaligus.
  perform pg_advisory_xact_lock(hashtext('pkg:' || v.tutor_id::text));

  v_local := v.schedule_start_date::timestamp + v.schedule_start_time;
  v_dt := v_local at time zone 'Asia/Jakarta';
  if v_dt <= now() then
    raise exception 'Pertemuan pertama sudah lewat. Pilih tanggal lain' using errcode = '22023';
  end if;

  -- Bila sudah pernah ditahan (panggilan ulang), mulai bersih.
  delete from public.bookings
   where package_purchase_id = v.id and status = 'pending_payment';

  for i in 0 .. (v.total_sesi - 1) loop
    v_local := (v.schedule_start_date::timestamp + v.schedule_start_time) + make_interval(days => i * 7);
    v_dt := v_local at time zone 'Asia/Jakarta';

    if not exists (
      select 1 from public.tutor_availability a
       where a.tutor_id = v.tutor_id
         and a.active
         and a.mode = v.mode
         and a.day_of_week = extract(dow from v_dt at time zone 'Asia/Jakarta')::int
         and a.start_time <= (v_dt at time zone 'Asia/Jakarta')::time
         and a.end_time >= (v_dt at time zone 'Asia/Jakarta')::time + make_interval(mins => v.duration_minutes)
    ) then
      raise exception 'Pertemuan % di luar jadwal ketersediaan tutor',
        to_char(v_dt at time zone 'Asia/Jakarta', 'DD Mon YYYY HH24:MI')
        using errcode = '22023';
    end if;

    if exists (
      select 1 from public.bookings b
       where b.status not in ('cancelled', 'expired', 'refunded')
         and b.scheduled_at < v_dt + make_interval(mins => v.duration_minutes)
         and b.scheduled_at + make_interval(mins => b.duration_minutes) > v_dt
         and (b.tutor_id = v.tutor_id or b.student_id = v.student_id)
    ) then
      raise exception 'Jadwal % sudah terisi (tutor atau kamu punya sesi lain)',
        to_char(v_dt at time zone 'Asia/Jakarta', 'DD Mon YYYY HH24:MI')
        using errcode = '22023';
    end if;

    insert into public.bookings (
      student_id, tutor_id, subject_id, jenjang, duration_minutes, mode, type,
      scheduled_at, price, discount, package_purchase_id, status, address, lock_expires_at
    ) values (
      v.student_id, v.tutor_id, v.subject_id, v.jenjang, v.duration_minutes, v.mode, 'privat',
      v_dt, v.price_per_session, v.price_per_session, v.id, 'pending_payment',
      case when v.mode = 'offline' then v.address end,
      now() + interval '30 minutes'
    );
    v_made := v_made + 1;
  end loop;

  return v_made;
end;
$$;

revoke all on function public.reserve_package_schedule(uuid) from public, anon, authenticated;
grant execute on function public.reserve_package_schedule(uuid) to service_role;

-- ============ 5. Aktifkan paket setelah pembayaran lunas ============
create or replace function public.activate_package(p_package_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v        public.package_purchases;
  v_last   timestamptz;
  v_expires timestamptz;
  v_count  integer;
begin
  select * into v from public.package_purchases where id = p_package_id for update;
  if v.id is null then
    raise exception 'Paket tidak ditemukan' using errcode = '22023';
  end if;

  select count(*) into v_count from public.bookings where package_purchase_id = v.id;

  if v.status = 'active' then
    return v_count; -- idempoten
  end if;
  if v.status <> 'pending_payment' then
    raise exception 'Paket tidak bisa diaktifkan (status %)', v.status using errcode = '22023';
  end if;

  update public.bookings
     set status = 'confirmed', lock_expires_at = null
   where package_purchase_id = v.id
     and status in ('pending_payment', 'expired');

  select max(scheduled_at) into v_last
    from public.bookings where package_purchase_id = v.id and status = 'confirmed';

  v_expires := now() + make_interval(months => case v.total_sesi when 4 then 1 when 8 then 2 else 3 end);
  if v_last is not null and v_last + interval '7 days' > v_expires then
    v_expires := v_last + interval '7 days';
  end if;

  update public.package_purchases
     set status = 'active',
         purchased_at = now(),
         expires_at = v_expires,
         sesi_terpakai = total_sesi, -- seluruh kuota terpakai sejak pertemuan dibuat
         lock_expires_at = null
   where id = v.id;

  return v_count;
end;
$$;

revoke all on function public.activate_package(uuid) from public, anon, authenticated;
grant execute on function public.activate_package(uuid) to service_role;

-- ============ 6. Batalkan tahanan paket (pembayaran gagal) ============
create or replace function public.cancel_package_reservation(p_package_id uuid, p_status text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v integer;
begin
  if p_status not in ('cancelled', 'expired') then
    raise exception 'Status tujuan tidak valid' using errcode = '22023';
  end if;

  update public.bookings
     set status = case when p_status = 'expired' then 'expired' else 'cancelled' end,
         lock_expires_at = null
   where package_purchase_id = p_package_id
     and status = 'pending_payment';
  get diagnostics v = row_count;

  update public.package_purchases
     set status = p_status, lock_expires_at = null
   where id = p_package_id
     and status = 'pending_payment';

  return v;
end;
$$;

revoke all on function public.cancel_package_reservation(uuid, text) from public, anon, authenticated;
grant execute on function public.cancel_package_reservation(uuid, text) to service_role;

-- ============ 7. Refund paket: hitung pertemuan yang belum berjalan ============
create or replace function public.refund_package(p_package_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v           public.package_purchases;
  v_remaining integer;
  v_refund    integer;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;

  select * into v from public.package_purchases where id = p_package_id for update;
  if v.id is null then
    raise exception 'Paket tidak ditemukan' using errcode = '22023';
  end if;
  if v.status not in ('active', 'expired') then
    raise exception 'Paket tidak bisa direfund (status %)', v.status using errcode = '22023';
  end if;

  -- Pertemuan yang belum berjalan (masih akan datang) dibatalkan dan direfund.
  select count(*) into v_remaining
  from public.bookings
  where package_purchase_id = p_package_id
    and status in ('pending_payment', 'confirmed')
    and scheduled_at > now();

  update public.bookings
     set status = 'cancelled', lock_expires_at = null
   where package_purchase_id = p_package_id
     and status in ('pending_payment', 'confirmed')
     and scheduled_at > now();

  v_refund := (v.price_total * v_remaining) / v.total_sesi;

  update public.package_purchases
     set status = 'refunded', refund_amount = v_refund
   where id = p_package_id;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'package.refund', 'package_purchases', p_package_id::text,
          jsonb_build_object('status', v.status, 'sesi_terpakai', v.sesi_terpakai,
                             'pertemuan_belum_berjalan', v_remaining),
          jsonb_build_object('refund_amount', v_refund, 'status', 'refunded'));

  return v_refund;
end;
$$;

-- ============ 8. Harga paket awal ============
-- Nilai awal diturunkan dari harga sesi lama (diskon 4=0%, 8=5%, 12=10%) supaya
-- tidak ada kombinasi yang kosong. Admin bebas mengubahnya kapan saja.
insert into public.package_prices (jenjang, duration_minutes, mode, total_sesi, price)
select pm.jenjang,
       pm.duration_minutes,
       pm.mode,
       s.total_sesi,
       floor(pm.price * s.total_sesi * (100 - s.discount) / 100.0)::int
from public.price_matrix pm
cross join (values (4, 0), (8, 5), (12, 10)) as s(total_sesi, discount)
where pm.type = 'privat' and pm.active
  and not exists (
    select 1 from public.package_prices pp
    where pp.jenjang = pm.jenjang
      and pp.duration_minutes = pm.duration_minutes
      and pp.mode = pm.mode
      and pp.total_sesi = s.total_sesi
      and pp.active
  );
