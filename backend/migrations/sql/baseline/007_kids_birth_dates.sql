-- Structured kids data: name + optional birth_date (ISO date string in JSON).
-- Run in Supabase SQL editor after 006_profile_fields.sql.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kids jsonb NOT NULL DEFAULT '[]';

-- Backfill from legacy kids_names array when present.
UPDATE public.profiles p
SET kids = (
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object('name', n, 'birth_date', null)
      ORDER BY ord
    ),
    '[]'::jsonb
  )
  FROM unnest(p.kids_names) WITH ORDINALITY AS t(n, ord)
)
WHERE p.kids = '[]'::jsonb
  AND p.kids_names IS NOT NULL
  AND cardinality(p.kids_names) > 0;

alter table public.profiles enable row level security;
