# watervoice

All-in-one container for [dc-water-watch](https://github.com/Burnt-Pancakes/dc-water-watch) (WaterWatch DMV).

One image runs Postgres (pg_cron, pg_net, vault), GoTrue, PostgREST, the Supabase Edge Runtime, the app and Caddy (automatic HTTPS), supervised by s6-overlay. No Lovable or Supabase Cloud account is needed.

This repo holds only the containerization. The app source is cloned from the upstream repo at build time (`APP_REPO` / `APP_REF` build args).

Status: early scaffold. The image is built by GitHub Actions and published to `ghcr.io/burnt-pancakes/watervoice`. Not yet verified end to end.

## Install on Unraid

1. In the repo's GitHub Packages settings, make the `watervoice` package public (first publish is private by default).
2. On the Unraid terminal:

       wget -O /boot/config/plugins/dockerMan/templates-user/my-watervoice.xml \
         https://raw.githubusercontent.com/Burnt-Pancakes/watervoice/main/unraid/watervoice.xml

3. Docker tab > Add Container > choose the `watervoice` user template. Set `Public URL` to how you reach it, e.g. `http://192.168.1.50:8088`, then Apply.
4. Open the WebUI. First boot takes a minute while migrations run. Watch progress in the container log.

## Build

Every push to `main` builds a linux/amd64 image. To build a different app commit or add arm64 (for Oracle Ampere), run the `publish-image` workflow manually and fill in `app_ref` / `platforms`.

Local build: `docker build -t watervoice:dev .` (see `docker/README.md` for settings and the first-build checklist).
