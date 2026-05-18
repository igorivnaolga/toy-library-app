-- Run in Supabase SQL Editor after `001_profiles.sql` and toys are seeded.
-- Member reservations: one row per booking; toy availability is updated by the API.

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  toy_id text not null references public.toys (toy_id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending', 'cancelled', 'completed')),
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  updated_at timestamptz default now()
);

-- At most one active (pending) booking per toy.
create unique index if not exists idx_bookings_one_pending_per_toy
  on public.bookings (toy_id)
  where status = 'pending';

-- A member cannot hold two pending bookings for the same toy.
create unique index if not exists idx_bookings_one_pending_per_user_toy
  on public.bookings (user_id, toy_id)
  where status = 'pending';

create index if not exists idx_bookings_user_id on public.bookings (user_id);
create index if not exists idx_bookings_toy_id on public.bookings (toy_id);
create index if not exists idx_bookings_status on public.bookings (status);

comment on table public.bookings is 'Member toy reservations (MVP); status pending → cancelled or completed';
comment on column public.bookings.status is 'pending = reserved; cancelled = member cancelled; completed = picked up / loan started';

-- RLS: mobile app calls FastAPI (DATABASE_URL), not PostgREST on this table.
-- Enabling RLS blocks anon/authenticated direct API access unless you add policies.
alter table public.bookings enable row level security;
