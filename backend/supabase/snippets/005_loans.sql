-- Run in Supabase SQL Editor after `003_bookings.sql` / `004_booking_pickup_date.sql`.
-- Active loans: check-out from a pending booking (or walk-in) → 2-week loan period.

create table if not exists public.loans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  toy_id text not null references public.toys (toy_id) on delete restrict,
  booking_id uuid references public.bookings (id) on delete set null,
  checked_out_at timestamptz not null default now(),
  due_date date not null,
  returned_at timestamptz,
  renewal_count integer not null default 0
    check (renewal_count >= 0),
  status text not null default 'active'
    check (status in ('active', 'returned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz default now()
);

-- One active loan per toy at a time.
create unique index if not exists idx_loans_one_active_per_toy
  on public.loans (toy_id)
  where status = 'active';

create index if not exists idx_loans_user_id on public.loans (user_id);
create index if not exists idx_loans_due_date on public.loans (due_date);
create index if not exists idx_loans_status on public.loans (status);

comment on table public.loans is 'Toy loans after check-out; default 2-week period with optional renewals';
comment on column public.loans.booking_id is 'Source reservation when check-out started from a pending booking';
comment on column public.loans.renewal_count is 'Number of renewals used; compare to categories.max_renewals';

alter table public.loans enable row level security;
