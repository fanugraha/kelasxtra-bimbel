-- Status pembayaran milik siswa yang sedang login, untuk layar QRIS yang memantau
-- kapan tagihan lunas. RLS `payments` hanya membuka baris booking, jadi pakai
-- helper definer yang mengecek kepemilikan di keempat jenis tagihan.

create or replace function public.my_payment_status(p_order_id text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.status
  from public.payments p
  where p.order_id = p_order_id
    and (
      exists (select 1 from public.bookings b
              where b.id = p.booking_id and b.student_id = auth.uid())
      or exists (select 1 from public.package_purchases pp
                 where pp.id = p.package_purchase_id and pp.student_id = auth.uid())
      or exists (select 1 from public.group_seats gs
                 where gs.id = p.group_seat_id and gs.student_id = auth.uid())
      or exists (select 1 from public.subscriptions s
                 where s.id = p.subscription_id and s.student_id = auth.uid())
    );
$$;
-- Supabase memberi `execute` langsung ke anon/authenticated saat fungsi dibuat,
-- jadi cabut dari anon secara eksplisit (lihat 20261019000045).
revoke all on function public.my_payment_status(text) from public;
revoke execute on function public.my_payment_status(text) from anon;
grant execute on function public.my_payment_status(text) to authenticated;
