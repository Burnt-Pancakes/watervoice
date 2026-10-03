# watervoice

All-in-one container for [dc-water-watch](https://github.com/Burnt-Pancakes/dc-water-watch) (WaterWatch DMV).

One image runs Postgres (pg_cron, pg_net, vault), GoTrue, PostgREST, the Supabase Edge Runtime, the app and Caddy (automatic HTTPS), supervised by s6-overlay. No Lovable or Supabase Cloud account is needed.

This repo holds only the containerization. The app source is cloned from the upstream repo at build time (`APP_REPO` / `APP_REF` build args).

Status: early scaffold, not yet built or tested.

## Build and run (test on Unraid or any Docker host)

    docker build -t watervoice:dev .
    docker run -d --name watervoice -p 80:80 -p 443:443 -e DOMAIN=water.example.org -v watervoice-data:/data watervoice:dev

Without `DOMAIN` it serves plain HTTP on port 80. See `docker/README.md` for environment variables and the first-build checklist.
