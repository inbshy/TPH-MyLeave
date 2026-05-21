-- RUN in Supabase SQL Editor — lets admins reassign employee group/company in the app.
-- Requires auth_user_role() from supabase/fix_login_profile.sql (run that first if login/profile fails).

drop policy if exists users_update_admin on public.users;
create policy users_update_admin
  on public.users for update to authenticated
  using (public.auth_user_role() = 'admin')
  with check (public.auth_user_role() = 'admin');

drop policy if exists employees_update_admin on public.employees;
create policy employees_update_admin
  on public.employees for update to authenticated
  using (public.auth_user_role() = 'admin')
  with check (public.auth_user_role() = 'admin');

create or replace function public.admin_update_employee_company(
  p_employee_id integer,
  p_company_id integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_name text;
  v_role text;
begin
  if public.auth_user_role() is distinct from 'admin' then
    raise exception 'Only admins can update employee assignment';
  end if;

  update public.users
  set company_id = p_company_id
  where employee_id = p_employee_id
  returning id, name, role into v_user_id, v_name, v_role;

  if v_user_id is null then
    raise exception 'Employee not found (employee_id %)', p_employee_id;
  end if;

  update public.employees
  set company_id = p_company_id
  where employee_id = p_employee_id;

  if not found then
    insert into public.employees (user_id, employee_id, company_id, name, role)
    values (v_user_id, p_employee_id, p_company_id, v_name, coalesce(v_role, 'employee'));
  end if;
end;
$$;

revoke all on function public.admin_update_employee_company(integer, integer) from public;
grant execute on function public.admin_update_employee_company(integer, integer) to authenticated;
