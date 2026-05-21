-- Company groups + leave request details (comments, attachments).
-- Run in Supabase SQL Editor after prior migrations.

-- ----- Company groups --------------------------------------------------------
create table if not exists public.company_groups (
  group_id serial primary key,
  "groupName" text not null unique
);

insert into public.company_groups ("groupName")
select 'Default Group'
where not exists (select 1 from public.company_groups limit 1);

alter table public.company
  add column if not exists group_id integer references public.company_groups (group_id) on delete restrict;

update public.company
set group_id = (select group_id from public.company_groups order by group_id limit 1)
where group_id is null;

-- ----- Leave request details -------------------------------------------------
alter table public.leave_requests
  add column if not exists employee_comment text not null default '';

alter table public.leave_requests
  add column if not exists attachment_path text not null default '';

alter table public.leave_requests
  add column if not exists admin_comment text not null default '';

alter table public.leave_requests
  add column if not exists rejected_reason text not null default '';

-- ----- RLS: company groups ---------------------------------------------------
alter table public.company_groups enable row level security;

drop policy if exists company_groups_select_all on public.company_groups;
create policy company_groups_select_all
  on public.company_groups for select to anon, authenticated using (true);

drop policy if exists company_groups_admin_write on public.company_groups;
create policy company_groups_admin_write
  on public.company_groups for all to authenticated
  using (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  )
  with check (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  );

-- Admin can insert companies
drop policy if exists company_admin_insert on public.company;
create policy company_admin_insert
  on public.company for insert to authenticated
  with check (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  );

drop policy if exists company_admin_update on public.company;
create policy company_admin_update
  on public.company for update to authenticated
  using (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  )
  with check (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  );

-- Managers/admins can read all employees in their company scope (admin: all)
drop policy if exists employees_admin_select on public.employees;
create policy employees_admin_select
  on public.employees for select to authenticated
  using (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
    or user_id = auth.uid()
    or exists (
      select 1 from public.users me
      where me.id = auth.uid() and me.role = 'manager' and me.company_id = employees.company_id
    )
  );

-- Storage bucket for leave attachments (create in Dashboard if this fails)
insert into storage.buckets (id, name, public)
values ('leave-attachments', 'leave-attachments', false)
on conflict (id) do nothing;

drop policy if exists leave_attachments_upload on storage.objects;
create policy leave_attachments_upload
  on storage.objects for insert to authenticated
  with check (bucket_id = 'leave-attachments');

drop policy if exists leave_attachments_read on storage.objects;
create policy leave_attachments_read
  on storage.objects for select to authenticated
  using (bucket_id = 'leave-attachments');
