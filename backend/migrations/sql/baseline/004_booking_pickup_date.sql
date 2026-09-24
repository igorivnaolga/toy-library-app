-- Run after `003_bookings.sql`.
-- Member-chosen pickup day (Wednesday or Saturday); validated by the API.

alter table public.bookings
  add column if not exists pickup_date date;

create index if not exists idx_bookings_pickup_date on public.bookings (pickup_date);

comment on column public.bookings.pickup_date is 'Library session day for pickup (Wed/Sat); required for new API bookings';

alter table public.bookings enable row level security;
