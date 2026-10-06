-- Rewrites Lovable-specific URLs/keys in cron jobs and vault secrets. Idempotent.
-- psql vars: base (Caddy internal), appbase (app on :3000), anon, cron
-- \gset stores the result in psql variables instead of printing it, so keys do not end up in the log.
SELECT set_config('ww.base', :'base', false) AS a, set_config('ww.appbase', :'appbase', false) AS b,
       set_config('ww.anon', :'anon', false) AS c, set_config('ww.cron', :'cron', false) AS d \gset

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

  -- Vault secrets are encrypted with the pgsodium root key. If that key changed (for example the container
  -- was recreated), existing rows can no longer be decrypted, and vault.update_secret fails on them.
  -- Replace the two secrets instead of updating them.
  DELETE FROM vault.secrets WHERE name IN ('cron_secret', 'ingest_url');
  PERFORM vault.create_secret(current_setting('ww.cron'), 'cron_secret');
  PERFORM vault.create_secret(current_setting('ww.appbase') || '/api/public/ingest', 'ingest_url');
END $$;
