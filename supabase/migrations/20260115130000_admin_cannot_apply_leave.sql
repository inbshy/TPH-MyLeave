-- Only employees may insert leave requests (blocks admin/manager at DB level).
drop policy if exists leave_insert_own on public.leave_requests;

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
