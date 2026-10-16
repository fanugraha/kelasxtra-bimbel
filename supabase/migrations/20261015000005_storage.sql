-- Fase 0 — storage buckets + policy dasar
-- avatars: publik (foto profil)
-- question-assets: privat (soal bergambar)
-- tutor-documents: privat (tidak dipakai di MVP — rekrutmen offline)

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('question-assets', 'question-assets', false),
  ('tutor-documents', 'tutor-documents', false)
on conflict (id) do nothing;

-- avatars: publik boleh baca, pemilik boleh tulis di folder miliknya ({user_id}/...)
create policy "avatars: baca publik"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars: unggah milik sendiri"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars: ubah milik sendiri"
  on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars: hapus milik sendiri"
  on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- question-assets: privat, hanya admin konten yang kelola
create policy "question-assets: admin kelola"
  on storage.objects for all
  using (bucket_id = 'question-assets' and public.is_admin())
  with check (bucket_id = 'question-assets' and public.is_admin());
