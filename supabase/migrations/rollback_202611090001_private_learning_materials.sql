-- Execute only as an explicit rollback after reviewing the backed-up policies.
-- This restores the prior bucket visibility and recreates the exact policy
-- expressions captured by the forward migration.

update storage.buckets
set public = true
where id = 'caslms-learning-materials';

do $$
declare
  policy_row record;
  role_list text;
  statement text;
begin
  for policy_row in
    select *
    from public.section_isolation_storage_policy_backup
    where migration_id = '202611090001'
  loop
    select string_agg(quote_ident(role_name::text), ', ')
      into role_list
    from unnest(policy_row.roles) as role_name;

    statement := format(
      'create policy %I on %I.%I as %s for %s to %s',
      policy_row.policyname,
      policy_row.schemaname,
      policy_row.tablename,
      case when policy_row.permissive = 'PERMISSIVE'
        then 'permissive' else 'restrictive' end,
      policy_row.cmd,
      role_list
    );
    if policy_row.qual is not null then
      statement := statement || format(' using (%s)', policy_row.qual);
    end if;
    if policy_row.with_check is not null then
      statement := statement || format(' with check (%s)', policy_row.with_check);
    end if;
    execute statement;
  end loop;
end
$$;
