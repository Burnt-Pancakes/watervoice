#!/command/with-contenv sh
set -e
. /etc/s6-overlay/scripts/env.sh
export PGPASSWORD="$POSTGRES_PASSWORD"
PSQL="psql -h 127.0.0.1 -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -q"
until pg_isready -h 127.0.0.1 -U supabase_admin -d postgres -q; do sleep 1; done

$PSQL -c "ALTER ROLE authenticator WITH PASSWORD '$POSTGRES_PASSWORD'" \
      -c "ALTER ROLE supabase_auth_admin WITH PASSWORD '$POSTGRES_PASSWORD'"
$PSQL -f /opt/ww/sql/00-storage-shim.sql
$PSQL -f /opt/ww/sql/01-helpers.sql

$PSQL -c "CREATE TABLE IF NOT EXISTS public.ww_app_migrations (name text PRIMARY KEY, applied_at timestamptz DEFAULT now())" \
      -c "REVOKE ALL ON public.ww_app_migrations FROM anon, authenticated"
for f in $(ls /opt/migrations/*.sql | sort); do
  n=$(basename "$f")
  if [ "$($PSQL -tAc "SELECT 1 FROM public.ww_app_migrations WHERE name='$n'")" != "1" ]; then
    echo "[ww] applying $n"
    sed -E "s/cron\.unschedule\(\s*'([^']+)'\s*\)/ww.unschedule_if_exists('\1')/g" "$f" > /tmp/ww-migration.sql
    $PSQL -1 -f /tmp/ww-migration.sql
    $PSQL -c "INSERT INTO public.ww_app_migrations(name) VALUES ('$n')"
  fi
done

$PSQL -v base="$SUPABASE_URL" -v appbase="http://127.0.0.1:3000" -v anon="$ANON_KEY" -v cron="$CRON_SECRET" -f /opt/ww/sql/10-localize-cron.sql
echo "[ww] bootstrap complete"
