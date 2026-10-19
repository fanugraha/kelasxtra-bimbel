-- Pengetatan hak akses untuk fungsi baru kebijakan uang (ganti hari + poin).
-- Sudah diterapkan ke produksi lewat MCP dengan nama `hardening_poin_ganti_hari`;
-- berkas ini adalah catatan lokal yang setara (idempoten, aman dijalankan ulang).
--
-- Anon tidak boleh memanggil fungsi-fungsi ini. Fungsi yang dibutuhkan klien
-- tetap dipegang role `authenticated` (dan di dalamnya tetap dicek kepemilikan/
-- peran), sedangkan `spend_credits` hanya untuk `service_role`.

revoke execute on function public.tutor_free_at(uuid, timestamptz, integer, text) from anon;
revoke execute on function public.slot_is_free(uuid, timestamptz, integer, uuid, uuid) from anon;
revoke execute on function public.request_reschedule(uuid, timestamptz, text) from anon;
revoke execute on function public.respond_reschedule(uuid, boolean, text) from anon;
revoke execute on function public.cancel_reschedule_request(uuid) from anon;
revoke execute on function public.expire_reschedule_requests() from anon;
revoke execute on function public.reschedule_booking(uuid, timestamptz, text) from anon;
revoke execute on function public.cancel_booking(uuid, text) from anon;
revoke execute on function public.student_credit_balance(uuid) from anon;
revoke execute on function public.my_credit_balance() from anon;
revoke execute on function public.apply_tutor_no_show(uuid) from anon;
revoke execute on function public.reschedule_no_show(uuid, timestamptz, text) from anon;
revoke execute on function public.grant_student_credit(uuid, integer, text, text) from anon;
revoke execute on function public.spend_credits(uuid, integer, text, uuid, uuid) from anon;
revoke execute on function public.cancel_package_with_credit(uuid, text) from anon;
revoke execute on function public.cancel_group_seat_with_credit(uuid, text) from anon;
