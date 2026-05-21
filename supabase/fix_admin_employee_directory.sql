-- RUN in Supabase SQL Editor — employee directory profile/role updates from the app.
-- Run fix_login_profile.sql first if auth_user_role() is missing.

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

create or replace function public.admin_change_user_role(
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.auth_user_role() is distinct from 'admin' then
    raise exception 'Only admins can change roles';
  end if;

  if p_role not in ('employee', 'manager', 'admin') then
    raise exception 'Invalid role';
  end if;

  update public.users set role = p_role where id = p_user_id;
  if not found then raise exception 'User not found'; end if;

  update public.employees set role = p_role where user_id = p_user_id;
end;
$$;

revoke all on function public.admin_change_user_role(uuid, text) from public;
grant execute on function public.admin_change_user_role(uuid, text) to authenticated;

create or replace function public.admin_update_user_profile(
  p_user_id uuid,
  p_name text,
  p_email text,
  p_staff_type text default 'permanent',
  p_company_id integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id integer;
  v_role text;
begin
  if public.auth_user_role() is distinct from 'admin' then
    raise exception 'Only admins can edit profiles';
  end if;

  update public.users
  set
    name = trim(p_name),
    email = trim(p_email),
    staff_type = coalesce(nullif(trim(p_staff_type), ''), 'permanent'),
    company_id = coalesce(p_company_id, company_id)
  where id = p_user_id
  returning employee_id, role into v_employee_id, v_role;

  if not found then raise exception 'User not found'; end if;

  update public.employees
  set
    name = trim(p_name),
    company_id = coalesce(p_company_id, company_id),
    role = coalesce(v_role, role)
  where user_id = p_user_id;

  if not found then
    insert into public.employees (user_id, employee_id, company_id, name, role)
    values (
      p_user_id,
      v_employee_id,
      coalesce(p_company_id, (select company_id from public.users where id = p_user_id)),
      trim(p_name),
      coalesce(v_role, 'employee')
    );
  end if;
end;
$$;

revoke all on function public.admin_update_user_profile(uuid, text, text, text, integer) from public;
grant execute on function public.admin_update_user_profile(uuid, text, text, text, integer) to authenticated;
