-- Enforce valid leave date ranges at the database level.
alter table public.leave_requests
  drop constraint if exists leave_requests_dates_order;

alter table public.leave_requests
  add constraint leave_requests_dates_order
  check (date_end >= date_start);

alter table public.leave_requests
  drop constraint if exists leave_requests_positive_days;

alter table public.leave_requests
  add constraint leave_requests_positive_days
  check ("totalLeave" >= 1);
