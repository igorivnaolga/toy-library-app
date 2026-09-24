-- Rental price scraped from SETLS item pages (stored in cents).
alter table public.toys
  add column if not exists rental_price_cents integer;

comment on column public.toys.rental_price_cents is
  'Toy rental price in NZD cents (from SETLS).';

alter table public.toys enable row level security;
