create table if not exists public.activity_logs (
  id text primary key,
  sequence_id bigint generated always as identity unique,
  event_type text not null check (
    event_type in ('login', 'logout', 'course_created', 'material_uploaded')
  ),
  actor_id text not null,
  actor_name text not null default '',
  actor_role text not null check (actor_role in ('student', 'instructor', 'admin')),
  session_auth_time bigint,
  target_id text,
  course_id text,
  title text,
  occurred_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists activity_logs_created_at_idx
  on public.activity_logs (created_at desc, sequence_id desc);

create index if not exists activity_logs_type_created_at_idx
  on public.activity_logs (event_type, created_at desc, sequence_id desc);

alter table public.activity_logs enable row level security;
alter table public.activity_logs force row level security;

revoke all on public.activity_logs from anon, authenticated;
revoke all on sequence public.activity_logs_sequence_id_seq
  from anon, authenticated;

grant select, insert, update on public.activity_logs to service_role;
grant usage, select on sequence public.activity_logs_sequence_id_seq
  to service_role;

comment on table public.activity_logs is
  'CASLMS audit events. Access is restricted to the verified activity-logs Edge Function.';
