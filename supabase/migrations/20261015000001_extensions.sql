-- Fase 0 — ekstensi & helper umum
-- Uang selalu integer rupiah. Waktu selalu timestamptz (UTC).

create extension if not exists pgcrypto;      -- gen_random_uuid(), digest()
create extension if not exists pg_cron;        -- auto-complete H+1 (Fase 6)
create extension if not exists pg_net;         -- panggil Edge Function dari DB

-- updated_at otomatis untuk semua tabel yang punya kolomnya
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
