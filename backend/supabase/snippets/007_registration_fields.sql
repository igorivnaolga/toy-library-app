-- Registration form fields from the Church Corner Toy Library paper form.
-- Run in Supabase SQL editor after earlier profile snippets.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS parent_b_name text,
  ADD COLUMN IF NOT EXISTS address_line1 text,
  ADD COLUMN IF NOT EXISTS address_line2 text,
  ADD COLUMN IF NOT EXISTS suburb text,
  ADD COLUMN IF NOT EXISTS mobile_phone text,
  ADD COLUMN IF NOT EXISTS alt_contact_name text,
  ADD COLUMN IF NOT EXISTS alt_contact_address text,
  ADD COLUMN IF NOT EXISTS alt_contact_phone text,
  ADD COLUMN IF NOT EXISTS heard_about_us text,
  ADD COLUMN IF NOT EXISTS skills text,
  ADD COLUMN IF NOT EXISTS text_reminders_consent boolean,
  ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS registered_at date;
