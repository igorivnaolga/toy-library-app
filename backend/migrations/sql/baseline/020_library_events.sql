-- Library events with bookable volunteer/member time slots.
-- Run in Supabase SQL Editor after earlier snippets.

create table if not exists public.library_events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  event_date date not null,
  end_date date not null,
  is_published boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_library_events_date
  on public.library_events (event_date);

create index if not exists idx_library_events_end_date
  on public.library_events (end_date);

-- If upgrading an existing database:
-- alter table public.library_events add column if not exists end_date date;
-- update public.library_events set end_date = event_date where end_date is null;

create table if not exists public.event_time_slots (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.library_events (id) on delete cascade,
  start_time time not null,
  end_time time not null,
  capacity integer not null check (capacity >= 1),
  audience text not null check (audience in ('volunteer', 'member')),
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);

create index if not exists idx_event_time_slots_event
  on public.event_time_slots (event_id);

create unique index if not exists idx_event_time_slots_unique
  on public.event_time_slots (event_id, start_time, end_time, audience);

create table if not exists public.event_bookings (
  id uuid primary key default gen_random_uuid(),
  slot_id uuid not null references public.event_time_slots (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  booked_at timestamptz not null default now(),
  unique (slot_id, user_id)
);

create index if not exists idx_event_bookings_user
  on public.event_bookings (user_id);

comment on table public.library_events is
  'Special library events admins create for volunteer help or member sign-up';
comment on column public.event_time_slots.audience is
  'volunteer = help run the event; member = attend/participate';

alter table public.library_events enable row level security;
alter table public.event_time_slots enable row level security;
alter table public.event_bookings enable row level security;
