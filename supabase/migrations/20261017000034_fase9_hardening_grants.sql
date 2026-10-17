-- Hardening Fase 9 — cabut EXECUTE fungsi sensitif dari anon/PUBLIC.
-- Temuan advisor: 41 fungsi SECURITY DEFINER bisa dipanggil `anon`.
-- Semua RPC klien tetap tersedia untuk `authenticated`; fungsi internal/trigger
-- hanya dipanggil dari definer/cron.

revoke execute on all functions in schema public from public, anon;

do $$
declare
  fname text;
  client_fns text[] := array[
    'is_admin', 'is_admin_role',
    'booking_participant', 'booking_is_student',
    'booking_has_student', 'booking_has_tutor', 'thread_participant',
    'distance_meters',
    'check_voucher', 'voucher_validate', 'set_price',
    'tutor_checkin', 'student_attend', 'mark_no_show',
    'save_session_note', 'complete_booking',
    'reschedule_booking', 'cancel_booking',
    'open_complaint', 'resolve_complaint', 'submit_review',
    'send_booking_message', 'mark_group_attendance',
    'start_attempt', 'submit_attempt',
    'ensure_booking_thread',
    'admin_save_question', 'admin_set_question_status',
    'admin_create_group_class', 'refund_package', 'refund_group_seat',
    'admin_generate_payroll', 'admin_approve_payroll',
    'admin_cancel_payroll', 'admin_mark_payroll_paid',
    'admin_correct_booking', 'admin_transfer_package', 'admin_metrics'
  ];
begin
  foreach fname in array client_fns loop
    execute format('grant execute on function public.%I to authenticated', fname);
  end loop;
end $$;

-- search_path tetap untuk fungsi yang belum di-set.
alter function public.group_discount(int) set search_path = public;
alter function public.distance_meters(double precision, double precision,
                                      double precision, double precision)
  set search_path = public;
