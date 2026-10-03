# sourced by every service: loads generated secrets and derives public URLs
set -a
[ -f /data/config/secrets.env ] && . /data/config/secrets.env
if [ -n "$DOMAIN" ]; then SITE_ADDRESS="$DOMAIN"; PUBLIC_URL="${PUBLIC_URL:-https://$DOMAIN}"; else SITE_ADDRESS=":80"; PUBLIC_URL="${PUBLIC_URL:-http://localhost}"; fi
SITE_URL="$PUBLIC_URL"
SUPABASE_URL="http://127.0.0.1:8080"
SUPABASE_PUBLISHABLE_KEY="$ANON_KEY"
SUPABASE_ANON_KEY="$ANON_KEY"
SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY"
DB_URL_ADMIN="postgres://supabase_admin:${POSTGRES_PASSWORD}@127.0.0.1:5432/postgres"
set +a
