#!/command/with-contenv sh
set -e
. /etc/s6-overlay/scripts/env.sh
rm -rf /opt/app && mkdir -p /opt/app && cp -a /opt/app-dist/. /opt/app/
grep -rIl -e __WW_SUPABASE_URL__ -e __WW_ANON_KEY__ /opt/app | while read -r f; do
  sed -i -e "s#__WW_SUPABASE_URL__#${PUBLIC_URL}#g" -e "s#__WW_ANON_KEY__#${ANON_KEY}#g" "$f"
done
echo "[ww] app rendered for $PUBLIC_URL"
