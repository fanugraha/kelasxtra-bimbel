-- Perbaikan: kursi yang dibatalkan tidak boleh memblokir pemesanan ulang.
-- Ganti unique(kelas, siswa) menjadi indeks unik parsial (kecuali status 'cancelled').

alter table public.group_seats
  drop constraint if exists group_seats_group_class_id_student_id_key;

create unique index if not exists group_seats_unique_active
  on public.group_seats (group_class_id, student_id)
  where status <> 'cancelled';
