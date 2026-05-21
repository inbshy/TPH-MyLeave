-- Run once if you already applied initial_schema.sql without auto employee_id.
-- Supabase SQL Editor: paste and execute.

create sequence if not exists public.employee_id_seq start with 1 increment by 1;

select setval(
  'public.employee_id_seq',
  coalesce((select max(employee_id) from public.users), 0) + 1
);

alter table public.users
  alter column employee_id set default nextval('public.employee_id_seq'::regclass);

alter sequence public.employee_id_seq owned by public.users.employee_id;
