-- Private helper schema (not exposed through PostgREST, which only serves public).
CREATE SCHEMA IF NOT EXISTS ww;

-- Lovable's live database already had cron jobs that the migrations unschedule.
-- On a fresh database they do not exist and cron.unschedule(name) raises an error.
-- bootstrap.sh rewrites cron.unschedule('name') to this helper before running each migration.
CREATE OR REPLACE FUNCTION ww.unschedule_if_exists(p_jobname text) RETURNS boolean
LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = p_jobname) THEN
    RETURN cron.unschedule(p_jobname);
  END IF;
  RETURN false;
END
$$;

REVOKE ALL ON FUNCTION ww.unschedule_if_exists(text) FROM PUBLIC;
