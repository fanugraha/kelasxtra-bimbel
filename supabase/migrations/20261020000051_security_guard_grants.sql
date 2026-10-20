-- Fungsi trigger tidak perlu dipanggil lewat RPC publik.
revoke execute on function public.guard_profile_self_update() from public, anon, authenticated;
revoke execute on function public.guard_tutor_self_update() from public, anon, authenticated;
