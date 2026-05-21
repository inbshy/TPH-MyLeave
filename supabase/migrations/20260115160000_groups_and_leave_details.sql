-- Group companies, leave comments/attachments, storage bucket setup notes.
-- Run in Supabase SQL Editor.

-- ----- company groups --------------------------------------------------------
create table if not exists public.company_groups (
  group_id serial primary key,
  "groupName" text not null unique
);

alter table public.company
  add column if not exists group_id integer references public.company_groups (group_id) on delete restrict;

-- ----- leave request details -------------------------------------------------
alter table public.leave_requests
  add column if not exists employee_comment text not null default '';

alter table public.leave_requests
  add column if not exists attachment_path text not null default '';

alter table public.leave_requests
  add column if not exists admin_comment text not null default '';

alter table public.leave_requests
  add column if not exists rejected_reason text not null default '';

-- ----- RLS: company_groups (readable for registration; admin manages) --------
alter table public.company_groups enable row level security;

drop policy if exists company_groups_select_public on public.company_groups;
create policy company_groups_select_public
  on public.company_groups for select to anon, authenticated using (true);

drop policy if exists company_groups_insert_admin on public.company_groups;
create policy company_groups_insert_admin
  on public.company_groups for insert to authenticated
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    )
  );

-- Admin insert companies (if not already present)
drop policy if exists company_insert_admin on public.company;
create policy company_insert_admin
  on public.company for insert to authenticated
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    )
  );

-- Admins read all users for employee balance report
drop policy if exists users_select_admin on public.users;
create policy users_select_admin
  on public.users for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.users me
      where me.id = auth.uid() and me.role in ('manager', 'admin')
    )
  );

-- ----- Storage: run supabase/fix_storage_attachments.sql in SQL Editor ----------
