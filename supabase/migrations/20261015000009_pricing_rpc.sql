-- Fase 2 — RPC ubah harga (price matrix) + riwayat + audit.
-- Perubahan harga = aksi sensitif: tulis audit_logs, versi lama jadi inactive (riwayat tersimpan).

create or replace function public.set_price(
  p_jenjang          text,
  p_duration_minutes int,
  p_mode             text,
  p_type             text,
  p_price            integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old     public.price_matrix;
  v_new_id  uuid;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_price < 0 then
    raise exception 'Harga tidak boleh negatif' using errcode = '22023';
  end if;

  select * into v_old
  from public.price_matrix
  where jenjang = p_jenjang
    and duration_minutes = p_duration_minutes
    and mode = p_mode
    and type = p_type
    and active
  limit 1;

  update public.price_matrix
    set active = false
    where jenjang = p_jenjang
      and duration_minutes = p_duration_minutes
      and mode = p_mode
      and type = p_type
      and active;

  insert into public.price_matrix (jenjang, duration_minutes, mode, type, price)
  values (p_jenjang, p_duration_minutes, p_mode, p_type, p_price)
  returning id into v_new_id;

  insert into public.audit_logs (actor_id, action, entity, entity_id, before_data, after_data)
  values (
    auth.uid(), 'price_matrix.update', 'price_matrix', v_new_id::text,
    case when v_old.id is null then null
         else jsonb_build_object('price', v_old.price) end,
    jsonb_build_object('jenjang', p_jenjang, 'duration_minutes', p_duration_minutes,
                       'mode', p_mode, 'type', p_type, 'price', p_price)
  );

  return v_new_id;
end;
$$;

grant execute on function public.set_price(text, int, text, text, integer) to authenticated;
