-- =============================================================================
-- TPH MyLeave — initial schema for Supabase (PostgreSQL)
-- =============================================================================
-- How to use:
--   1. Open Supabase Dashboard → SQL Editor → New query.
--   2. Paste this entire file and run once on a new (empty) project.
--   3. Set SUPABASE_URL and SUPABASE_ANON_KEY in your app’s `test.env`.
--
-- Re-run: drop dependent objects first (uncomment block at bottom), then run again.
-- =============================================================================

-- ----- company ---------------------------------------------------------------
create table public.company (
  company_id serial primary key,
  "companyName" text not null
);

comment on table public.company is 'Organizations; used by registration and admin.';

-- Monotonic ids for new profiles (registration omits employee_id; DB fills it).
create sequence public.employee_id_seq start with 1 increment by 1;

-- ----- public.users (app profiles; id = auth.users id) -----------------------
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  employee_id integer not null default nextval('public.employee_id_seq'::regclass) unique,
  name text not null,
  email text not null,
  role text not null check (role in ('employee', 'manager', 'admin')),
  staff_type text not null default 'permanent',
  company_id integer not null references public.company (company_id) on delete restrict,
  created_at timestamptz not null default now()
);

create index users_company_id_idx on public.users (company_id);
create index users_role_idx on public.users (role);

comment on table public.users is 'App profile per auth user; role drives dashboard and approvals.';

alter sequence public.employee_id_seq owned by public.users.employee_id;

-- ----- employees -------------------------------------------------------------
create table public.employees (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  employee_id integer not null unique references public.users (employee_id) on delete cascade,
  company_id integer not null references public.company (company_id) on delete restrict,
  name text not null,
  role text not null default 'employee'
);

create index employees_user_id_idx on public.employees (user_id);
create index employees_company_id_idx on public.employees (company_id);

comment on table public.employees is 'Mirrors staff row; links auth user to employee_id for leave.';

-- ----- leave_requests (column names match Dart LeaveRequest JSON) ------------
create table public.leave_requests (
  id bigserial primary key,
  date_start timestamptz not null,
  date_end timestamptz not null,
  leave_type text not null check (
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
  ),
  "employeeID" integer not null references public.employees (employee_id) on delete restrict,
  "totalLeave" integer not null,
  "approveBy" text not null default '',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected'))
);

create index leave_requests_employee_id_idx on public.leave_requests ("employeeID");
create index leave_requests_status_idx on public.leave_requests (status);
create index leave_requests_date_start_idx on public.leave_requests (date_start desc);

comment on table public.leave_requests is 'Leave applications; camelCase columns match Flutter model.';

-- =============================================================================
-- Row Level Security (RLS)
-- =============================================================================

alter table public.company enable row level security;
alter table public.users enable row level security;
alter table public.employees enable row level security;
alter table public.leave_requests enable row level security;

-- company: readable without login (registration dropdown uses anon key).
create policy company_select_public
  on public.company
  for select
  to anon, authenticated
  using (true);

-- users: each auth user manages their own profile row.
create policy users_select_own
  on public.users
  for select
  to authenticated
  using (id = auth.uid());

create policy users_insert_own
  on public.users
  for insert
  to authenticated
  with check (id = auth.uid());

create policy users_update_own
  on public.users
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- employees: own row; managers/admins can read same-company staff.
create policy employees_select_visible
  on public.employees
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.users me
      where me.id = auth.uid()
        and me.role in ('manager', 'admin')
        and me.company_id = employees.company_id
    )
  );

create policy employees_insert_own
  on public.employees
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy employees_update_own
  on public.employees
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- leave_requests: employees see own; managers/admins see all (matches app queries).
create policy leave_select_visible
  on public.leave_requests
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.users me
      where me.id = auth.uid()
        and me.role in ('manager', 'admin')
    )
    or "employeeID" in (
      select u.employee_id from public.users u where u.id = auth.uid()
      union
      select e.employee_id from public.employees e where e.user_id = auth.uid()
    )
  );

create policy leave_insert_employees_only
  on public.leave_requests
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.users me
      where me.id = auth.uid()
        and me.role = 'employee'
    )
    and "employeeID" in (
      select u.employee_id from public.users u where u.id = auth.uid()
      union
      select e.employee_id from public.employees e where e.user_id = auth.uid()
    )
  );

create policy leave_update_managers
  on public.leave_requests
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.users me
      where me.id = auth.uid()
        and me.role in ('manager', 'admin')
    )
  )
  with check (
    exists (
      select 1
      from public.users me
      where me.id = auth.uid()
        and me.role in ('manager', 'admin')
    )
  );

-- =============================================================================
-- Seed (at least one company required before self-registration works)
-- =============================================================================

insert into public.company ("companyName")
select 'Demo Company'
where not exists (select 1 from public.company limit 1);

-- =============================================================================
-- Optional: destructive reset (uncomment, run, then run this file again)
-- =============================================================================
-- drop policy if exists company_select_public on public.company;
-- drop policy if exists users_select_own on public.users;
-- drop policy if exists users_insert_own on public.users;
-- drop policy if exists users_update_own on public.users;
-- drop policy if exists employees_select_visible on public.employees;
-- drop policy if exists employees_insert_own on public.employees;
-- drop policy if exists employees_update_own on public.employees;
-- drop policy if exists leave_select_visible on public.leave_requests;
-- drop policy if exists leave_insert_own on public.leave_requests;
-- drop policy if exists leave_update_managers on public.leave_requests;
-- drop table if exists public.leave_requests cascade;
-- drop table if exists public.employees cascade;
-- drop table if exists public.users cascade;
-- drop table if exists public.company cascade;
