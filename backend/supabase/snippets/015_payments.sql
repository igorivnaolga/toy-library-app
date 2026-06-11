-- Payment ledger (Phase 1: record charges and staff-recorded payments; no card gateway).

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  payment_type text not null
    check (payment_type in ('membership', 'bond', 'rental')),
  amount_cents integer not null check (amount_cents > 0),
  currency text not null default 'NZD',
  status text not null default 'pending'
    check (status in (
      'pending',
      'paid_cash',
      'paid_eftpos',
      'paid_bank',
      'refunded',
      'cancelled'
    )),
  description text,
  booking_id uuid references public.bookings (id) on delete set null,
  loan_id uuid references public.loans (id) on delete set null,
  toy_id text references public.toys (toy_id) on delete set null,
  recorded_by uuid references public.profiles (id) on delete set null,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_payments_user_id on public.payments (user_id);
create index if not exists idx_payments_status on public.payments (status);
create index if not exists idx_payments_user_pending on public.payments (user_id)
  where status = 'pending';

comment on table public.payments is
  'Member charges and staff-recorded payments (cash/EFTPOS/bank). Phase 1 ledger only.';
comment on column public.payments.payment_type is 'membership | bond | rental';
comment on column public.payments.status is 'pending until staff or admin records payment';

alter table public.payments enable row level security;
