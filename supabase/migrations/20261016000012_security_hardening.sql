-- Perbaikan advisor keamanan (kecil)
-- 1) set_updated_at: tetapkan search_path (advisor function_search_path_mutable).
-- 2) handle_new_user: fungsi trigger, jangan bisa dipanggil lewat RPC publik.

alter function public.set_updated_at() set search_path = public;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
