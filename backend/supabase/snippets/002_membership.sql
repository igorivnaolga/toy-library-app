-- Run in Supabase SQL Editor if `profiles` already exists without membership columns.
-- (Fresh installs that use the updated `001_profiles.sql` already include these.)

alter table public.profiles
  add column if not exists membership_tier text;

alter table public.profiles
  add column if not exists volunteer_confirmed boolean not null default false;

-- Optional: enforce allowed tier values at the database layer (skip if it already exists).
do $$
begin
  alter table public.profiles
    add constraint profiles_membership_tier_allowed
    check (
      membership_tier is null
      or membership_tier in ('casual', 'non_duty', 'duty')
    );
exception
  when duplicate_object then null;
end $$;

comment on column public.profiles.membership_tier is 'MVP: casual | non_duty | duty (chosen in onboarding)';
comment on column public.profiles.volunteer_confirmed is 'For duty tier: admin must confirm before role becomes volunteer';
