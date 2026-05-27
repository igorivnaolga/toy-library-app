-- Run in Supabase SQL Editor after `001_profiles.sql`.
-- Volunteer duty roster: time slots volunteers can book for desk shifts.

create table if not exists public.duty_sessions (
  id uuid primary key default gen_random_uuid(),
  session_date date not null,
  start_time time not null,
  end_time time not null,
  volunteer_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz default now(),
  check (end_time > start_time)
);

-- One slot per date/time range (admin-created or volunteer self-booked).
create unique index if not exists idx_duty_sessions_slot
  on public.duty_sessions (session_date, start_time, end_time);

create index if not exists idx_duty_sessions_date
  on public.duty_sessions (session_date);

create index if not exists idx_duty_sessions_volunteer
  on public.duty_sessions (volunteer_id)
  where volunteer_id is not null;

comment on table public.duty_sessions is
  'Duty roster slots; volunteer_id null = open slot, set = booked shift';
comment on column public.duty_sessions.volunteer_id is
  'Volunteer on duty for this slot; null means the slot is still open';

alter table public.duty_sessions enable row level security;
