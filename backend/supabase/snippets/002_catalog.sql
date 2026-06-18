-- Run after `001_profiles.sql`, before `002_membership.sql`.
-- Base catalog tables; extra toy columns are added in later snippets (009–013, etc.).
-- Seed rows: python -m app.scripts.seed_from_csv (from backend/).

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  code varchar(64) not null unique,
  label text not null unique,
  max_renewals integer,
  reservable boolean,
  toy_count_current integer,
  toy_count_total integer,
  pct_label varchar(32)
);

create table if not exists public.toys (
  toy_id varchar(32) primary key,
  name text not null,
  category_id uuid references public.categories (id),
  age_range text,
  status varchar(64),
  manufacturer text,
  description text,
  category_label text,
  cv_learn_samples integer not null default 0
);

create index if not exists ix_toys_category_id on public.toys (category_id);
create index if not exists ix_toys_name on public.toys (name);
create index if not exists ix_toys_status on public.toys (status);
create index if not exists ix_toys_category_label on public.toys (category_label);

create table if not exists public.toy_images (
  id uuid primary key default gen_random_uuid(),
  toy_id varchar(32) not null unique references public.toys (toy_id) on delete cascade,
  filename varchar(512)
);

-- RLS: app uses FastAPI (DATABASE_URL), not PostgREST on these tables.
alter table public.categories enable row level security;
alter table public.toys enable row level security;
alter table public.toy_images enable row level security;
