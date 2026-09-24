-- Push notification device tokens and send dedupe log.
-- Run after `001_profiles.sql` (any time before enabling FCM in production).

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token varchar(512) not null unique,
  platform varchar(16) not null default 'android',
  updated_at timestamptz not null default now()
);

create index if not exists ix_device_tokens_user_id
  on public.device_tokens (user_id);

create table if not exists public.push_notification_logs (
  dedupe_key varchar(256) primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  sent_at timestamptz not null default now()
);

create index if not exists ix_push_notification_logs_user_id
  on public.push_notification_logs (user_id);

-- RLS: app uses FastAPI (DATABASE_URL), not PostgREST on these tables.
alter table public.device_tokens enable row level security;
alter table public.push_notification_logs enable row level security;
