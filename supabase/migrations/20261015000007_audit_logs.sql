-- Fase 1 — audit_logs (jejak aksi sensitif: payout, refund, koreksi absensi, suspend, ubah harga)
-- Insert hanya lewat service role (Edge Function) atau trigger DB; client tak boleh menulis.

create table public.audit_logs (
  id          bigint generated always as identity primary key,
  actor_id    uuid references public.profiles (id) on delete set null,
  action      text not null,
  entity      text not null,
  entity_id   text,
  before_data jsonb,
  after_data  jsonb,
  created_at  timestamptz not null default now()
);

create index audit_logs_entity_idx  on public.audit_logs (entity, entity_id);
create index audit_logs_actor_idx   on public.audit_logs (actor_id);
create index audit_logs_created_idx on public.audit_logs (created_at desc);

alter table public.audit_logs enable row level security;

-- Hanya admin yang boleh membaca. Tak ada policy insert/update/delete untuk client (deny-by-default).
create policy "audit_logs: admin baca"
  on public.audit_logs for select
  using (public.is_admin());
