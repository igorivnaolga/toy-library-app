-- SETLS historical catalog snapshots for admin statistics comparison.

create table if not exists setls_import_runs (
  id uuid primary key default gen_random_uuid(),
  imported_at timestamptz not null default now(),
  source_label text not null default 'export_imgs',
  toy_count int,
  category_count int
);

create table if not exists setls_category_stats (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references setls_import_runs(id) on delete cascade,
  code text not null,
  description text,
  current_toys int,
  total_toys int,
  pct_share numeric(6, 2),
  reservable boolean,
  max_renewals int
);

create index if not exists setls_category_stats_run_id_idx
  on setls_category_stats (run_id);

create table if not exists setls_toy_status_counts (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references setls_import_runs(id) on delete cascade,
  status text not null,
  toy_count int not null
);

create index if not exists setls_toy_status_counts_run_id_idx
  on setls_toy_status_counts (run_id);

alter table public.setls_import_runs enable row level security;
alter table public.setls_category_stats enable row level security;
alter table public.setls_toy_status_counts enable row level security;
