-- RUN in Supabase SQL Editor — lets admins edit company & group names in the app.

create or replace function public.auth_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.users where id = auth.uid() limit 1;
$$;

revoke all on function public.auth_user_role() from public;
grant execute on function public.auth_user_role() to authenticated;

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
