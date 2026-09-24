-- Public toy catalog photos bucket (path stored in toy_images.filename).
-- Run in Supabase SQL editor after toys / toy_images exist.
--
-- Uploads and deletes are done by the FastAPI backend using the service role key.
-- Clients read photos via the public URL (no auth required).

INSERT INTO storage.buckets (id, name, public)
VALUES ('toy-photos', 'toy-photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "toy_photos_select_public" ON storage.objects;
CREATE POLICY "toy_photos_select_public"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'toy-photos');
