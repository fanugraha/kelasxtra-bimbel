-- Helper internal hanya dipanggil dari fungsi/Edge Function service role.
-- Jangan biarkan user login memanggilnya langsung lewat /rest/v1/rpc.
revoke execute on function public.voucher_validate(text, uuid, integer) from authenticated, anon;
revoke execute on function public.ensure_booking_thread(uuid) from authenticated, anon;
revoke execute on function public.ensure_earning(uuid) from authenticated, anon;
