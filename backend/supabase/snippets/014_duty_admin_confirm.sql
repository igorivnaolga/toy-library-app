-- Run after `008_duty_sessions.sql`.
-- Admin must confirm a volunteer's booked shift on the duty day before desk access.

alter table public.duty_sessions
  add column if not exists admin_confirmed_at timestamptz,
  add column if not exists admin_confirmed_by uuid references public.profiles (id) on delete set null;

comment on column public.duty_sessions.admin_confirmed_at is
  'When an admin confirmed this volunteer for desk duty (required on the duty day)';
comment on column public.duty_sessions.admin_confirmed_by is
  'Admin profile id that confirmed the shift';
