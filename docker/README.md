# WaterWatch all-in-one image (UNTESTED SCAFFOLD)

## Run
    docker run -d --name waterwatch \
      -p 80:80 -p 443:443 \
      -e DOMAIN=water.example.org \
      -v waterwatch-data:/data \
      watervoice:dev

No DOMAIN = plain HTTP on :80. Secrets are generated on first boot into /data/config/secrets.env (back this up with the volume).

## Optional env
| Var | Purpose |
|---|---|
| DOMAIN | Public hostname; Caddy gets a Let's Encrypt cert (ports 80+443 must reach the container) |
| PUBLIC_URL | Override public URL (e.g. LAN testing on a non-standard port, or behind another proxy) |
| SMTP_HOST/PORT/USER/PASS/FROM | Auth emails (sign-up confirmation, resets) |
| AUTO_CONFIRM=true | Skip email confirmation (no SMTP) |
| RESEND_API_KEY | Alert emails |
| ANTHROPIC_API_KEY | AI explanations |

## First-build spike checklist (things not yet verified)
1. `npm run build` produces `.output/server/index.mjs` with NITRO_PRESET=node-server (Lovable's vite config bundles the Cloudflare plugin). If not, run the Worker build under workerd instead and change `s6-rc.d/app/run`.
2. `cloudflare:workers` ASSETS usage in `src/lib/routingAssetFetch.server.ts` needs a Node fallback (read static files from disk). Ship it as a file in `patches/`.
3. Pin image tags in the Dockerfile; confirm binary paths (`/usr/local/bin/auth`, `/bin/postgrest`, `/usr/local/bin/edge-runtime`) and the GoTrue migrations dir.
4. Confirm the Postgres base image already has the `storage` schema (else `00-storage-shim.sql` covers it) and that `docker-entrypoint.sh postgres -D /etc/postgresql` is its real CMD.
5. Check that all app migrations apply cleanly on an empty DB, and that cron.job commands were rewritten (`SELECT jobname, command FROM cron.job`).
6. Node 24 binary vs the base image's glibc.
7. Edge functions: compare repo copies with what Lovable has deployed.
8. Set explicit timeout_milliseconds on cron jobs (pg_net default is 5 s).
9. CMC and CBIBS sources block datacenter IPs: run `cmc-push.mjs` from a home IP with INGEST_URL=https://DOMAIN/functions/v1/ingest-cmc and CRON_SECRET from secrets.env.

## Debugging
    docker logs -f watervoice
    docker exec -it watervoice sh
    docker exec watervoice cat /data/config/secrets.env
    docker exec watervoice s6-rc -a list
