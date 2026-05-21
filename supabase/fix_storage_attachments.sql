-- =============================================================================
-- RUN ONCE in Supabase → SQL Editor (fixes leave attachment upload failures)
-- =============================================================================

-- Role helper (same as fix_login_profile.sql — safe to run again)
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

-- Bucket: leave-attachments (private, 50 MB per file)
insert into storage.buckets (id, name, public, file_size_limit)
values ('leave-attachments', 'leave-attachments', false, 52428800)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit;

-- Upload: authenticated users → folder named with their auth user id
drop policy if exists leave_attachments_insert_own on storage.objects;
create policy leave_attachments_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'leave-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Read: file owner, or manager/admin (for approvals)
drop policy if exists leave_attachments_select on storage.objects;
create policy leave_attachments_select
  on storage.objects for select to authenticated
  using (
    bucket_id = 'leave-attachments'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.auth_user_role() in ('manager', 'admin')
    )
  );

-- Update/delete own uploads (optional retry / replace)
drop policy if exists leave_attachments_update_own on storage.objects;
create policy leave_attachments_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'leave-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists leave_attachments_delete_own on storage.objects;
create policy leave_attachments_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'leave-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
