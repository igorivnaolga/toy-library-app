-- Account top-ups and paying charges from account credit.

alter table public.payments drop constraint if exists payments_payment_type_check;
alter table public.payments add constraint payments_payment_type_check
  check (payment_type in ('membership', 'bond', 'rental', 'top_up'));

alter table public.payments drop constraint if exists payments_status_check;
alter table public.payments add constraint payments_status_check
  check (status in (
    'pending',
    'paid_cash',
    'paid_eftpos',
    'paid_bank',
    'paid_credit',
    'refunded',
    'cancelled'
  ));

comment on column public.payments.payment_type is 'membership | bond | rental | top_up';
comment on column public.payments.status is
  'pending until staff records payment; paid_credit when settled from account credit';
