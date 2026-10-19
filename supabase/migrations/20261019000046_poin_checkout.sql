-- Pemakaian poin (student_credits) saat pembayaran.
--
-- Poin dipotong SETELAH pembayaran benar-benar lunas (settlement), bukan saat
-- Snap dibuat — supaya poin tidak hilang bila pembayaran kedaluwarsa. Jumlah
-- poin yang akan dipakai dicatat di baris `payments` ini oleh Edge Function
-- (create-snap / create-package-snap / create-group-seat-snap), lalu dipotong
-- di `applyPaymentOutcome` (midtrans-webhook / reconcile-payments /
-- resolve-payment-review) lewat RPC `spend_credits` yang hanya bisa dipanggil
-- service_role.

alter table public.payments
  add column if not exists credit_amount integer not null default 0
    check (credit_amount >= 0);

comment on column public.payments.credit_amount is
  'Poin (Rp) yang dipakai memotong pembayaran ini; dipotong saat settlement.';
