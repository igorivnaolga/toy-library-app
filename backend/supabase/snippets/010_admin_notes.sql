-- Admin-only notes on member profiles (not exposed to members).
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS admin_notes text;
