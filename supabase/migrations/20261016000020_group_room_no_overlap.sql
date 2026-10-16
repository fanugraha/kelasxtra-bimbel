-- Fase 4 — anti double-booking ruangan: pertemuan tidak boleh bertabrakan dengan
-- kelas lain (status open/confirmed) di ruangan yang sama.

create or replace function public.admin_create_group_class(
  p_tutor uuid,
  p_subject uuid,
  p_jenjang text,
  p_mode text,
  p_room_id uuid,
  p_duration int,
  p_total_sesi int,
  p_days int[],
  p_start_date date,
  p_time time
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id      uuid;
  v_price   int;
  v_disc    int;
  v_total   int;
  v_days    int[];
  v_weeks   int;
  v_w       int;
  v_day     int;
  v_seq     int := 0;
  v_dt      date;
  v_ts      timestamptz;
  v_first   timestamptz;
  v_deadline timestamptz;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin' using errcode = '42501';
  end if;
  if p_total_sesi not in (4, 8, 12) then
    raise exception 'total_sesi harus 4, 8, atau 12' using errcode = '22023';
  end if;
  if p_days is null or array_length(p_days, 1) is null then
    raise exception 'Pilih minimal satu hari' using errcode = '22023';
  end if;
  if p_mode = 'offline' and p_room_id is null then
    raise exception 'Kelas offline wajib memilih ruangan' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.tutor_subjects
    where tutor_id = p_tutor and subject_id = p_subject and jenjang = p_jenjang
  ) then
    raise exception 'Tutor tidak mengajar kombinasi ini' using errcode = '22023';
  end if;

  select array_agg(d order by d) into v_days from unnest(p_days) as d;
  if exists (select 1 from unnest(v_days) as d where d < 1 or d > 7) then
    raise exception 'Hari tidak valid' using errcode = '22023';
  end if;
  if p_total_sesi % array_length(v_days, 1) <> 0 then
    raise exception 'Jumlah sesi harus kelipatan jumlah hari per minggu' using errcode = '22023';
  end if;
  v_weeks := p_total_sesi / array_length(v_days, 1);

  select price into v_price
  from public.price_matrix
  where jenjang = p_jenjang and duration_minutes = p_duration
    and mode = p_mode and type = 'grup' and active
  limit 1;
  if v_price is null then
    raise exception 'Harga grup belum diset untuk kombinasi ini' using errcode = '22023';
  end if;

  v_disc := public.group_discount(p_total_sesi);
  v_total := (v_price * p_total_sesi * (100 - v_disc)) / 100;

  v_dt := p_start_date + ((v_days[1] - extract(isodow from p_start_date)::int + 7) % 7);
  v_first := (v_dt::timestamp + p_time) at time zone 'Asia/Jakarta';
  v_deadline := ((date_trunc('day', v_first at time zone 'Asia/Jakarta')
                  - interval '1 day' + interval '20 hours') at time zone 'Asia/Jakarta');

  insert into public.group_classes (
    tutor_id, subject_id, jenjang, mode, room_id, duration_minutes,
    total_sesi, discount_percent, price_per_session, price_total,
    min_seats, max_seats, status, min_confirm_deadline
  ) values (
    p_tutor, p_subject, p_jenjang, p_mode, p_room_id, p_duration,
    p_total_sesi, v_disc, v_price, v_total,
    3, 5, 'open', v_deadline
  ) returning id into v_id;

  for v_w in 0 .. v_weeks - 1 loop
    foreach v_day in array v_days loop
      v_dt := p_start_date
              + ((v_day - extract(isodow from p_start_date)::int + 7) % 7)
              + (v_w * 7);
      v_ts := (v_dt::timestamp + p_time) at time zone 'Asia/Jakarta';

      if p_room_id is not null and exists (
        select 1
        from public.group_sessions gs
        join public.group_classes gc on gc.id = gs.group_class_id
        where gc.room_id = p_room_id
          and gc.status in ('open', 'confirmed')
          and gs.scheduled_at < v_ts + make_interval(mins => p_duration)
          and gs.scheduled_at + make_interval(mins => gc.duration_minutes) > v_ts
      ) then
        raise exception 'Ruangan sudah dipakai pada %',
          to_char(v_ts at time zone 'Asia/Jakarta', 'DD Mon HH24:MI') using errcode = '22023';
      end if;

      v_seq := v_seq + 1;
      insert into public.group_sessions (group_class_id, seq, scheduled_at)
      values (v_id, v_seq, v_ts);
    end loop;
  end loop;

  return v_id;
end;
$$;

revoke all on function public.admin_create_group_class(uuid, uuid, text, text, uuid, int, int, int[], date, time)
  from public, anon, authenticated;
grant execute on function public.admin_create_group_class(uuid, uuid, text, text, uuid, int, int, int[], date, time)
  to authenticated;
