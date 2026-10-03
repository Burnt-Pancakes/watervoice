-- Rewrites Lovable-specific URLs/keys in cron jobs and vault secrets. Idempotent.
-- psql vars: base (Caddy internal), appbase (app on :3000), anon, cron
SELECT set_config('ww.base', :'base', false), set_config('ww.appbase', :'appbase', false),
       set_config('ww.anon', :'anon', false), set_config('ww.cron', :'cron', false);

DO $$
DECLARE j record;
BEGIN
  FOR j IN SELECT jobid, command FROM cron.job LOOP
    PERFORM cron.alter_job(j.jobid, command :=
      regexp_replace(
        regexp_replace(
          regexp_replace(j.command,
            'https://[a-z0-9]+\.supabase\.co', current_setting('ww.base'), 'g'),
          'https://project--[a-z0-9-]+\.lovable\.app', current_setting('ww.appbase'), 'g'),
        'sb_publishable_[A-Za-z0-9_-]+', current_setting('ww.anon'), 'g'));
  END LOOP;

  -- vault: create or update
  IF EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'cron_secret') THEN
    PERFORM vault.update_secret((SELECT id FROM vault.secrets WHERE name='cron_secret'), current_setting('ww.cron'));
  ELSE
    PERFORM vault.create_secret(current_setting('ww.cron'), 'cron_secret');
  END IF;
  IF EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'ingest_url') THEN
    PERFORM vault.update_secret((SELECT id FROM vault.secrets WHERE name='ingest_url'), current_setting('ww.appbase') || '/api/public/ingest');
  ELSE
    PERFORM vault.create_secret(current_setting('ww.appbase') || '/api/public/ingest', 'ingest_url');
  END IF;
END $$;
