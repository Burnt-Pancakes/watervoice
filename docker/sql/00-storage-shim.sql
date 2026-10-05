-- The Supabase Postgres image ships a minimal storage schema (no storage-api migrations).
-- App migrations insert into storage.buckets (id, name, public) and add policies on storage.objects,
-- so make sure the columns they need exist. Idempotent.
CREATE SCHEMA IF NOT EXISTS storage;
CREATE TABLE IF NOT EXISTS storage.buckets (
  id text PRIMARY KEY, name text NOT NULL, owner uuid,
  created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());
ALTER TABLE storage.buckets ADD COLUMN IF NOT EXISTS public boolean DEFAULT false;
ALTER TABLE storage.buckets ADD COLUMN IF NOT EXISTS file_size_limit bigint;
ALTER TABLE storage.buckets ADD COLUMN IF NOT EXISTS allowed_mime_types text[];
CREATE TABLE IF NOT EXISTS storage.objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text REFERENCES storage.buckets(id),
  name text, owner uuid, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(),
  metadata jsonb);
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
