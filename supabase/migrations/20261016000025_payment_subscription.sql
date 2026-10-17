-- Fase 5 — tautkan payment ke langganan (agar webhook bisa mengaktifkan/memperpanjang).

alter table public.payments
  add column if not exists subscription_id uuid
    references public.subscriptions (id) on delete set null;

create index if not exists payments_subscription_idx
  on public.payments (subscription_id);
