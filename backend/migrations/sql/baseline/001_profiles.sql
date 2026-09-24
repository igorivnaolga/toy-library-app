-- Run in Supabase SQL Editor (once per project).
-- Creates app roles for authenticated users and auto-inserts a profile on signup.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'guest'
    check (role in ('guest', 'member', 'volunteer', 'admin')),
  full_name text,
  membership_tier text
    check (membership_tier is null or membership_tier in ('casual', 'non_duty', 'duty')),
  volunteer_confirmed boolean not null default false,
  updated_at timestamptz default now()
);

-- New users start as guest; promote to member/volunteer/admin via SQL or admin UI later.
-- compatibility: use EXECUTE PROCEDURE on Postgres 11–13; FUNCTION on 14+ (both work on Supabase).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role)
  values (new.id, 'guest');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

comment on table public.profiles is 'App roles for Toy Library; linked to auth.users';

-- RLS: app uses FastAPI (DATABASE_URL), not PostgREST on this table.
alter table public.profiles enable row level security;
