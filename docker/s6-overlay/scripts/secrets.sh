#!/command/with-contenv sh
set -e
mkdir -p /data/postgres /data/config /data/backups
chown -R postgres:postgres /data/postgres
if [ ! -f /data/config/secrets.env ]; then
  node /opt/ww/gen-secrets.mjs > /data/config/secrets.env
  chmod 600 /data/config/secrets.env
  echo "[ww] generated new secrets in /data/config/secrets.env"
fi
