-- Review the rows saved below before applying this migration in production.
-- It makes the learning-material bucket private and removes every direct
-- storage.objects policy that mentions that bucket. CASLMS then uses verified
-- Edge Function signed upload/download operations only.

create table if not exists public.section_isolation_storage_policy_backup (
  migration_id text not null,
  schemaname text not null,
  tablename text not null,
  policyname text not null,
  permissive text not null,
  roles name[] not null,
  cmd text not null,
  qual text,
  with_check text,
  backed_up_at timestamptz not null default now(),
  primary key (migration_id, schemaname, tablename, policyname)
);

revoke all on public.section_isolation_storage_policy_backup from anon, authenticated;

insert into public.section_isolation_storage_policy_backup (
  migration_id, schemaname, tablename, policyname, permissive,
  roles, cmd, qual, with_check
)
select
  '202611090001', schemaname, tablename, policyname, permissive,
  roles, cmd, qual, with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and (
    coalesce(qual, '') like '%caslms-learning-materials%'
    or coalesce(with_check, '') like '%caslms-learning-materials%'
  )
on conflict do nothing;

do $$
declare
  policy_row record;
begin
  for policy_row in
    select policyname
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and (
        coalesce(qual, '') like '%caslms-learning-materials%'
        or coalesce(with_check, '') like '%caslms-learning-materials%'
      )
  loop
    execute format('drop policy %I on storage.objects', policy_row.policyname);
  end loop;
end
$$;

update storage.buckets
set public = false
where id = 'caslms-learning-materials';
