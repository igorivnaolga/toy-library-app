-- Profile fields for kids names and avatar storage path.
-- Run in Supabase SQL editor after earlier snippets.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kids_names  text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS avatar_path text;

-- Public avatars bucket (path stored in profiles.avatar_path).
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Authenticated users can upload/update their own avatar object.
DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
CREATE POLICY "avatars_insert_own"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
CREATE POLICY "avatars_update_own"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "avatars_select_public" ON storage.objects;
CREATE POLICY "avatars_select_public"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');

alter table public.profiles enable row level security;
