-- Phase 1: cancel/edit pending, manager mapping, notifications, scoped approvals.

-- ----- cancelled status ------------------------------------------------------
alter table public.leave_requests drop constraint if exists leave_requests_status_check;
alter table public.leave_requests
  add constraint leave_requests_status_check
  check (status in ('pending', 'approved', 'rejected', 'cancelled'));

-- ----- manager assignment ----------------------------------------------------
alter table public.users
  add column if not exists manager_user_id uuid references public.users (id) on delete set null;

create index if not exists users_manager_user_id_idx on public.users (manager_user_id);

-- ----- in-app notifications ----------------------------------------------------
create table if not exists public.leave_notifications (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  leave_id bigint references public.leave_requests (id) on delete set null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists leave_notifications_user_id_idx
  on public.leave_notifications (user_id, created_at desc);

alter table public.leave_notifications enable row level security;

drop policy if exists leave_notifications_select_own on public.leave_notifications;
create policy leave_notifications_select_own
  on public.leave_notifications for select to authenticated
  using (user_id = auth.uid());

drop policy if exists leave_notifications_update_own on public.leave_notifications;
create policy leave_notifications_update_own
  on public.leave_notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ----- visibility helper -----------------------------------------------------
create or replace function public.can_view_leave(p_employee_id integer)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users me
    where me.id = auth.uid()
      and (
        me.role = 'admin'
        or p_employee_id in (
          select u.employee_id from public.users u where u.id = auth.uid()
          union
          select e.employee_id from public.employees e where e.user_id = auth.uid()
        )
        or (
          me.role = 'manager'
          and exists (
            select 1
            from public.users emp
            where emp.employee_id = p_employee_id
              and (
                emp.manager_user_id = me.id
                or (
                  emp.manager_user_id is null
                  and emp.company_id = me.company_id
                )
              )
          )
        )
      )
  );
$$;

revoke all on function public.can_view_leave(integer) from public;
grant execute on function public.can_view_leave(integer) to authenticated;

-- ----- RLS: leave visibility -------------------------------------------------
drop policy if exists leave_select_visible on public.leave_requests;
create policy leave_select_visible
  on public.leave_requests for select to authenticated
  using (public.can_view_leave("employeeID"));

drop policy if exists leave_update_managers on public.leave_requests;
create policy leave_update_managers
  on public.leave_requests for update to authenticated
  using (
    public.auth_user_role() in ('manager', 'admin')
    and public.can_view_leave("employeeID")
  )
  with check (
    public.auth_user_role() in ('manager', 'admin')
    and public.can_view_leave("employeeID")
  );

-- ----- RPC: cancel / update pending (employee) -------------------------------
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
  where lr.id = p_leave_id and lr.status = 'pending';

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
  set status = 'cancelled', rejected_reason = 'Cancelled by employee'
  where id = p_leave_id;
end;
$$;

create or replace function public.update_pending_leave(
  p_leave_id bigint,
  p_date_start timestamptz,
  p_date_end timestamptz,
  p_leave_type text,
  p_total_leave integer,
  p_employee_comment text default '',
  p_attachment_path text default ''
)
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
  where lr.id = p_leave_id and lr.status = 'pending';

  if v_employee_id is null then
    raise exception 'Leave not found or not pending';
  end if;

  if not exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.employee_id = v_employee_id
  ) then
    raise exception 'Not allowed to edit this leave';
  end if;

  update public.leave_requests
  set
    date_start = p_date_start,
    date_end = p_date_end,
    leave_type = p_leave_type,
    "totalLeave" = p_total_leave,
    employee_comment = coalesce(p_employee_comment, ''),
    attachment_path = coalesce(p_attachment_path, '')
  where id = p_leave_id;
end;
$$;

revoke all on function public.cancel_pending_leave(bigint) from public;
grant execute on function public.cancel_pending_leave(bigint) to authenticated;
revoke all on function public.update_pending_leave(
  bigint, timestamptz, timestamptz, text, integer, text, text
) from public;
grant execute on function public.update_pending_leave(
  bigint, timestamptz, timestamptz, text, integer, text, text
) to authenticated;

-- ----- RPC: assign manager (admin) -------------------------------------------
create or replace function public.assign_employee_manager(
  p_employee_id integer,
  p_manager_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.auth_user_role() is distinct from 'admin' then
    raise exception 'Only admins can assign managers';
  end if;

  if p_manager_user_id is not null and not exists (
    select 1 from public.users m
    where m.id = p_manager_user_id and m.role = 'manager'
  ) then
    raise exception 'Manager user not found or not a manager role';
  end if;

  update public.users
  set manager_user_id = p_manager_user_id
  where employee_id = p_employee_id and role = 'employee';

  if not found then
    raise exception 'Employee not found';
  end if;
end;
$$;

revoke all on function public.assign_employee_manager(integer, uuid) from public;
grant execute on function public.assign_employee_manager(integer, uuid) to authenticated;

-- ----- RPC: create in-app notification -----------------------------------------
create or replace function public.create_leave_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_leave_id bigint default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.leave_notifications (user_id, title, body, leave_id)
  values (p_user_id, p_title, p_body, p_leave_id);
end;
$$;

revoke all on function public.create_leave_notification(uuid, text, text, bigint) from public;
grant execute on function public.create_leave_notification(uuid, text, text, bigint) to authenticated;

create or replace function public.notify_leave_event(
  p_leave_id bigint,
  p_event text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_leave public.leave_requests%rowtype;
  v_emp_user_id uuid;
  v_emp_name text;
  v_manager_id uuid;
  v_title text;
  v_body text;
begin
  select * into v_leave from public.leave_requests where id = p_leave_id;
  if not found then return; end if;

  select u.id, u.name, u.manager_user_id
  into v_emp_user_id, v_emp_name, v_manager_id
  from public.users u
  where u.employee_id = v_leave."employeeID";

  v_title := case p_event
    when 'submitted' then 'Leave submitted'
    when 'approved' then 'Leave approved'
    when 'rejected' then 'Leave rejected'
    when 'cancelled' then 'Leave cancelled'
    else 'Leave update'
  end;

  v_body := v_emp_name || ': ' || v_leave.leave_type || ' '
    || to_char(v_leave.date_start::date, 'YYYY-MM-DD') || ' to '
    || to_char(v_leave.date_end::date, 'YYYY-MM-DD') || ' (' || p_event || ')';

  if p_event = 'submitted' then
    if v_emp_user_id is not null then
      perform public.create_leave_notification(
        v_emp_user_id, 'Leave submitted', 'Your leave request was submitted.', p_leave_id
      );
    end if;
    if v_manager_id is not null then
      perform public.create_leave_notification(
        v_manager_id,
        'Approval needed',
        v_emp_name || ' submitted leave for your review.',
        p_leave_id
      );
    end if;
  elsif p_event in ('approved', 'rejected', 'cancelled') then
    if v_emp_user_id is not null then
      perform public.create_leave_notification(v_emp_user_id, v_title, v_body, p_leave_id);
    end if;
  end if;
end;
$$;

revoke all on function public.notify_leave_event(bigint, text) from public;
grant execute on function public.notify_leave_event(bigint, text) to authenticated;

-- Admin read/update manager_user_id on any user
drop policy if exists users_update_admin on public.users;
create policy users_update_admin
  on public.users for update to authenticated
  using (public.auth_user_role() = 'admin')
  with check (public.auth_user_role() = 'admin');
