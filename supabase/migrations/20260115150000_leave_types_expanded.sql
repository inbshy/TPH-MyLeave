-- Expand allowed leave_type values (keeps legacy mc/el for old rows).
alter table public.leave_requests
  drop constraint if exists leave_requests_leave_type_check;

alter table public.leave_requests
  add constraint leave_requests_leave_type_check
  check (
    leave_type in (
      'annual',
      'sick',
      'maternity',
      'hospitalisation',
      'paternity',
      'compassionate',
      'unpaid',
      'mc',
      'el'
    )
  );
