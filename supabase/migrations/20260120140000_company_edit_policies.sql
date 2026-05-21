-- Allow admins to update company and group names.

drop policy if exists company_groups_update_admin on public.company_groups;
create policy company_groups_update_admin
  on public.company_groups for update to authenticated
  using (public.auth_user_role() = 'admin')
  with check (public.auth_user_role() = 'admin');

drop policy if exists company_update_admin on public.company;
create policy company_update_admin
  on public.company for update to authenticated
  using (public.auth_user_role() = 'admin')
  with check (public.auth_user_role() = 'admin');
