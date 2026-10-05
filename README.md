# watervoice

All-in-one container for WaterWatch DMV, a civic water-quality advisory app for the DC Metro area. The app source lives in [waterwatch](https://github.com/Burnt-Pancakes/waterwatch); this repo only builds and packages it.

One image runs Postgres (pg_cron, pg_net, vault), GoTrue, PostgREST, the Supabase Edge Runtime, the app and Caddy (automatic HTTPS), supervised by s6-overlay. No Lovable or Supabase Cloud account is needed.

Status: early scaffold. The image is built by GitHub Actions and published to `ghcr.io/burnt-pancakes/watervoice`. Not yet verified end to end.

## Quick start

1. Get a free CARTO basemap key (next section).
2. Install the container (Unraid or plain Docker, below).
3. Open the app. First boot takes a minute while the database migrations run; watch the container log for `[ww] bootstrap complete`.
4. Optional: configure email (SMTP or Resend) and AI explanations (Anthropic key).
5. If you host in a datacenter, read "Hosting from a datacenter" below, or the CMC data source will stay empty.

## Get a CARTO basemap key

The map uses CARTO basemap tiles, which require an API key.

1. Go to https://carto.com/basemaps/apikey/ and fill in the form. No CARTO account is needed; the key is emailed to you.
2. Set it as `CARTO_API_KEY` (Unraid template field, or `-e CARTO_API_KEY=...` for Docker).
3. Request your own key for each deployment. Do not reuse another organization's key and do not commit yours to a repository.
4. The key is embedded in the page that browsers download, so treat it as a quota identifier rather than a password. Check CARTO's current free-tier limits and terms (non-commercial vs commercial use) at https://carto.com/basemaps/ .

Without a key the container still starts, but it logs a warning and the basemap shows an API-key watermark or fails to load.

## Install on Unraid

1. In this repo's GitHub Packages settings, make the `watervoice` package public (the first publish is private by default).
2. On the Unraid terminal:

       wget -O /boot/config/plugins/dockerMan/templates-user/my-watervoice.xml \
         https://raw.githubusercontent.com/Burnt-Pancakes/watervoice/main/unraid/watervoice.xml

3. Docker tab > Add Container > choose the `watervoice` user template. Fill in `CARTO API key`, and set `Public URL` to how you reach it, e.g. `http://192.168.1.50:8088`. Click Apply.

## Install with Docker

    docker run -d --name watervoice --restart unless-stopped \
      -p 80:80 -p 443:443 \
      -e DOMAIN=water.example.org \
      -e CARTO_API_KEY=your-key \
      -v watervoice-data:/data \
      ghcr.io/burnt-pancakes/watervoice:latest

With `DOMAIN` set, Caddy obtains a Let's Encrypt certificate automatically (ports 80 and 443 must reach the container). Without it the app serves plain HTTP; then set `PUBLIC_URL` to the address browsers use.

## Hosting from a datacenter

Some data sources refuse connections from datacenter IP addresses (cloud providers such as Oracle Cloud, AWS, Azure or a VPS). Upstream documents this for the Chesapeake Monitoring Cooperative (CMC) bacteria data, which resets connections from cloud IPs, and expects errors from the CBIBS buoy source as well.

If you host in a datacenter, those sources will return nothing unless you relay the data from a home or office connection:

1. Run `cmc_to_sql/cmc-push.mjs` (Node 22 or newer, no install step) on a machine with a residential or office IP, on a schedule (cron, Windows Task Scheduler).
2. Give it a `.env` file next to the script with `INGEST_URL=https://YOUR-DOMAIN/functions/v1/ingest-cmc` and `CRON_SECRET=` set to the value of `CRON_SECRET` in `/data/config/secrets.env` inside your data volume.
3. Run it with `node --env-file=.env cmc-push.mjs`.

Hosting on a home server (for example Unraid) behind a residential connection avoids the problem entirely.

## Settings

| Variable | Purpose |
|---|---|
| CARTO_API_KEY | Basemap key (required for a working map) |
| DOMAIN | Public hostname; enables automatic HTTPS |
| PUBLIC_URL | Browser-facing URL when not using DOMAIN |
| AUTO_CONFIRM | `true` skips email confirmation on sign-up |
| SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM | Auth emails |
| RESEND_API_KEY | Water-status alert emails |
| ANTHROPIC_API_KEY | AI explanations |

Secrets for the database and JWTs are generated on first boot into `/data/config/secrets.env`. Back up the `/data` volume.

## Build

Every push to `main` builds a linux/amd64 image. To build a different app commit or add arm64 (for Oracle Ampere), run the `publish-image` workflow manually and fill in `app_ref` / `platforms`.

See `docker/README.md` for the first-build checklist.
