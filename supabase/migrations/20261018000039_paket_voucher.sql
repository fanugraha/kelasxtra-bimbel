-- Fase 12 — Voucher untuk pembelian paket.
-- Melanjutkan alur voucher booking (Fase 2) ke paket. Validasi + kunci kuota
-- memakai fungsi generik yang sudah ada (`voucher_validate`, `check_voucher`,
-- `reserve_voucher`). Di sini ditambahkan tautan redemption ke paket + fungsi
-- penanda terpakai / pelepasan kuota, dan refund yang menghitung uang net
-- (setelah diskon voucher) — karena diskon 100% ditanggung platform, tutor
-- tetap menerima 75% harga normal per pertemuan.

-- ============ 1. Tautan redemption ke paket ============
alter table public.voucher_redemptions
  add column if not exists package_purchase_id uuid
    references public.package_purchases (id) on delete set null;

create index if not exists voucher_redemptions_package_idx
  on public.voucher_redemptions (package_purchase_id);

-- ============ 2. Snapshot voucher pada paket ============
alter table public.package_purchases
  add column if not exists voucher_id uuid
    references public.vouchers (id) on delete set null,
  -- Diskon rupiah dari voucher (0 = tanpa voucher). Uang yang dibayar siswa
  -- = price_total - discount.
  add column if not exists discount integer not null default 0
    check (discount >= 0);

-- ============ 3. Tautkan redemption ke paket ============
create or replace function public.attach_voucher_redemption_package(
  p_redemption_id uuid,
  p_package_id uuid
) returns void
language sql
security definer
set search_path = public
as $$
  update public.voucher_redemptions
     set package_purchase_id = p_package_id
   where id = p_redemption_id;
$$;

revoke all on function public.attach_voucher_redemption_package(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.attach_voucher_redemption_package(uuid, uuid)
  to service_role;

-- ============ 4. Tandai terpakai (pembayaran lunas) ============
create or replace function public.consume_voucher_for_package(p_package_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.voucher_redemptions
     set status = 'used'
   where package_purchase_id = p_package_id and status = 'locked';
$$;

revoke all on function public.consume_voucher_for_package(uuid)
  from public, anon, authenticated;
grant execute on function public.consume_voucher_for_package(uuid) to service_role;

-- ============ 5. Lepas kunci + kembalikan kuota ============
-- Dipakai saat pembayaran gagal/kedaluwarsa, DAN saat paket direfund
-- (lepas juga yang berstatus 'used' agar kuota voucher kembali ke siswa).
create or replace function public.release_voucher_for_package(p_package_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in
    select id, voucher_id
    from public.voucher_redemptions
    where package_purchase_id = p_package_id and status in ('locked', 'used')
  loop
    update public.voucher_redemptions set status = 'released' where id = r.id;
    update public.vouchers set used = greatest(0, used - 1) where id = r.voucher_id;
  end loop;
end;
$$;

revoke all on function public.release_voucher_for_package(uuid)
  from public, anon, authenticated;
grant execute on function public.release_voucher_for_package(uuid) to service_role;

-- ============ 6. Refund paket: berbasis uang net (setelah diskon) ============
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

  -- Refund proporsional dari uang yang benar-benar dibayar (price_total - discount).
  v_refund := ((v.price_total - v.discount) * v_remaining) / v.total_sesi;

  update public.package_purchases
     set status = 'refunded', refund_amount = v_refund
   where id = p_package_id;

  -- Kembalikan kuota voucher (bila ada) karena transaksi dibatalkan.
  perform public.release_voucher_for_package(p_package_id);

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (auth.uid(), 'package.refund', 'package_purchases', p_package_id::text,
          jsonb_build_object('status', v.status, 'sesi_terpakai', v.sesi_terpakai,
                             'pertemuan_belum_berjalan', v_remaining),
          jsonb_build_object('refund_amount', v_refund, 'status', 'refunded'));

  return v_refund;
end;
$$;
