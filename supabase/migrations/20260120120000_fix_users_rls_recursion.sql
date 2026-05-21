-- Fix "infinite recursion detected in policy for relation users" on login.
-- Prefer running supabase/fix_login_profile.sql (same fixes, easier to find).

drop policy if exists users_select_admin on public.users;

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

drop policy if exists users_select_admin on public.users;
create policy users_select_admin
  on public.users for select to authenticated
  using (
    id = auth.uid()
    or public.auth_user_role() in ('manager', 'admin')
  );

-- Same pattern on other policies that subquery public.users.
drop policy if exists company_groups_insert_admin on public.company_groups;
create policy company_groups_insert_admin
  on public.company_groups for insert to authenticated
  with check (public.auth_user_role() = 'admin');

drop policy if exists company_insert_admin on public.company;
create policy company_insert_admin
  on public.company for insert to authenticated
  with check (public.auth_user_role() = 'admin');

create or replace function public.get_my_profile()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select to_json(u) from public.users u where u.id = auth.uid() limit 1;
$$;

revoke all on function public.get_my_profile() from public;
grant execute on function public.get_my_profile() to authenticated;
