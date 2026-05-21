-- HR/admin features: directory, roles, multi-level approval, audit trail.

-- ----- multi-level approval statuses -----------------------------------------
alter table public.leave_requests drop constraint if exists leave_requests_status_check;
alter table public.leave_requests
  add constraint leave_requests_status_check
  check (status in (
    'pending', 'pending_manager', 'pending_admin',
    'approved', 'rejected', 'cancelled'
  ));

update public.leave_requests
set status = 'pending_manager'
where status = 'pending';

alter table public.leave_requests
  add column if not exists updated_at timestamptz not null default now();

-- ----- approval audit trail --------------------------------------------------
create table if not exists public.leave_approval_audit (
  id bigserial primary key,
  leave_id bigint not null references public.leave_requests (id) on delete cascade,
  actor_user_id uuid references auth.users (id) on delete set null,
  actor_name text not null default '',
  actor_role text not null default '',
  action text not null,
  comment text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists leave_approval_audit_leave_id_idx
  on public.leave_approval_audit (leave_id, created_at);

alter table public.leave_approval_audit enable row level security;

drop policy if exists leave_audit_select_visible on public.leave_approval_audit;
create policy leave_audit_select_visible
  on public.leave_approval_audit for select to authenticated
  using (
    exists (
      select 1 from public.leave_requests lr
      where lr.id = leave_id
        and public.can_view_leave(lr."employeeID")
    )
  );

-- ----- audit helper ----------------------------------------------------------
create or replace function public.log_leave_audit(
  p_leave_id bigint,
  p_action text,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_role text;
begin
  select name, role into v_name, v_role
  from public.users where id = auth.uid();

  insert into public.leave_approval_audit (
    leave_id, actor_user_id, actor_name, actor_role, action, comment
  ) values (
    p_leave_id, auth.uid(), coalesce(v_name, 'Unknown'), coalesce(v_role, ''), p_action, coalesce(p_comment, '')
  );
end;
$$;

revoke all on function public.log_leave_audit(bigint, text, text) from public;
grant execute on function public.log_leave_audit(bigint, text, text) to authenticated;

-- ----- multi-level approve / reject ------------------------------------------
create or replace function public.process_leave_approval(
  p_leave_id bigint,
  p_action text,
  p_comment text default '',
  p_rejected_reason text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_employee_id integer;
  v_role text;
begin
  v_role := public.auth_user_role();

  select status, "employeeID" into v_status, v_employee_id
  from public.leave_requests where id = p_leave_id;

  if v_status is null then
    raise exception 'Leave request not found';
  end if;

  if not public.can_view_leave(v_employee_id) then
    raise exception 'Not allowed to act on this leave';
  end if;

  if p_action = 'reject' then
    if v_status not in ('pending', 'pending_manager', 'pending_admin') then
      raise exception 'Leave is not pending';
    end if;
    update public.leave_requests
    set status = 'rejected',
        rejected_reason = coalesce(p_rejected_reason, 'Rejected'),
        admin_comment = coalesce(p_comment, ''),
        updated_at = now()
    where id = p_leave_id;
    perform public.log_leave_audit(p_leave_id, 'rejected', coalesce(p_rejected_reason, p_comment));
    return;
  end if;

  if p_action = 'approve' then
    if v_role = 'manager' then
      if v_status not in ('pending', 'pending_manager') then
        raise exception 'Not awaiting manager approval';
      end if;
      update public.leave_requests
      set status = 'pending_admin', updated_at = now()
      where id = p_leave_id;
      perform public.log_leave_audit(p_leave_id, 'manager_approved', p_comment);
      return;
    end if;

    if v_role = 'admin' then
      if v_status not in ('pending', 'pending_manager', 'pending_admin') then
        raise exception 'Leave is not pending';
      end if;
      update public.leave_requests
      set status = 'approved',
          admin_comment = coalesce(p_comment, ''),
          rejected_reason = '',
          updated_at = now()
      where id = p_leave_id;
      perform public.log_leave_audit(p_leave_id, 'final_approved', p_comment);
      return;
    end if;

    raise exception 'Only managers or admins can approve';
  end if;

  raise exception 'Unknown action';
end;
$$;

revoke all on function public.process_leave_approval(bigint, text, text, text) from public;
grant execute on function public.process_leave_approval(bigint, text, text, text) to authenticated;

-- ----- admin: change role ----------------------------------------------------
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

-- ----- admin: update profile -------------------------------------------------
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
  where id = p_user_id;

  if not found then raise exception 'User not found'; end if;

  update public.employees
  set name = trim(p_name),
      company_id = coalesce(p_company_id, company_id)
  where user_id = p_user_id;
end;
$$;

revoke all on function public.admin_update_user_profile(uuid, text, text, text, integer) from public;
grant execute on function public.admin_update_user_profile(uuid, text, text, text, integer) to authenticated;

-- ----- submit leave -> pending_manager ---------------------------------------
create or replace function public.cancel_pending_leave(p_leave_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id integer;
begin
  select lr."employeeID" into v_employee_id
  from public.leave_requests lr
  where lr.id = p_leave_id and lr.status in ('pending', 'pending_manager', 'pending_admin');

  if v_employee_id is null then
    raise exception 'Leave not found or not pending';
  end if;

  if not exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.employee_id = v_employee_id
  ) then
    raise exception 'Not allowed to cancel this leave';
  end if;

  update public.leave_requests
  set status = 'cancelled', rejected_reason = 'Cancelled by employee', updated_at = now()
  where id = p_leave_id;

  perform public.log_leave_audit(p_leave_id, 'cancelled', 'Cancelled by employee');
end;
$$;

-- New inserts default to pending_manager via trigger
create or replace function public.leave_requests_default_status()
returns trigger
language plpgsql
as $$
begin
  if new.status is null or new.status = 'pending' then
    new.status := 'pending_manager';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists leave_requests_default_status_trg on public.leave_requests;
create trigger leave_requests_default_status_trg
  before insert on public.leave_requests
  for each row execute function public.leave_requests_default_status();

create or replace function public.leave_requests_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists leave_requests_touch_updated_at_trg on public.leave_requests;
create trigger leave_requests_touch_updated_at_trg
  before update on public.leave_requests
  for each row execute function public.leave_requests_touch_updated_at();
