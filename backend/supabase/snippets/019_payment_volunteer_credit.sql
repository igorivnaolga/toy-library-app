-- Volunteer duty session credit (+$5) linked to duty roster shifts.

alter table public.payments
  add column if not exists duty_session_id uuid
  references public.duty_sessions (id) on delete set null;

alter table public.payments drop constraint if exists payments_payment_type_check;
alter table public.payments add constraint payments_payment_type_check
  check (payment_type in ('membership', 'bond', 'rental', 'top_up', 'volunteer_credit'));

alter table public.payments drop constraint if exists payments_status_check;
alter table public.payments add constraint payments_status_check
  check (status in (
    'pending',
    'paid_cash',
    'paid_eftpos',
    'paid_bank',
    'paid_credit',
    'granted',
    'refunded',
    'cancelled'
  ));

create unique index if not exists idx_payments_volunteer_duty_session
  on public.payments (duty_session_id)
  where payment_type = 'volunteer_credit' and duty_session_id is not null;

comment on column public.payments.duty_session_id is
  'Duty roster shift when payment_type is volunteer_credit';
