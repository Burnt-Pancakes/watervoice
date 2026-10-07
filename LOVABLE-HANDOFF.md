# Handoff: running WaterWatch DMV without Lovable

For the app owner and his Lovable workspace. Written 2026-10-07. Status: working prototype, not production.

## 1. Why this exists

The goal is that any organization can host WaterWatch for free, with one container and no Lovable or Supabase Cloud account. The prototype runs on a home server (Unraid) and is meant to move to an Oracle Cloud free VM. Convenience matters: adoption goes up when the install is one `docker run` or one Unraid template.

## 2. How to use this document with Lovable

Lovable cannot import or point at an existing GitHub repository. Its Git sync is export-only and always creates a new repository ([Lovable docs](https://docs.lovable.dev/integrations/git-sync-overview)). Two ways to get this to Lovable:

1. Paste this file into a Lovable chat as the brief for the work in section 8 and 9.
2. Add this file to the owner's own repo (for example `docs/CONTAINERIZATION.md`) through a pull request. Commits on the synced branch appear in the Lovable project.

## 3. Repositories

| Repo | Purpose |
|---|---|
| [rajivsundar/dc-water-watch](https://github.com/rajivsundar/dc-water-watch) | Original app, managed by Lovable. Unchanged by this work. |
| [Burnt-Pancakes/waterwatch](https://github.com/Burnt-Pancakes/waterwatch) | Sanitized snapshot of the app with no git history. The container builds from this. |
| [Burnt-Pancakes/watervoice](https://github.com/Burnt-Pancakes/watervoice) | The containerization: Dockerfile, process supervisor, Caddy, SQL helpers, CI, Unraid template. |

Image: `ghcr.io/burnt-pancakes/watervoice:latest`, built by GitHub Actions on every push to `main`.

## 4. Architecture

    Browser -> Caddy (80/443, automatic HTTPS)
                 /rest/v1/*       -> PostgREST   (127.0.0.1:3001)
                 /auth/v1/*       -> GoTrue      (127.0.0.1:9999)
                 /functions/v1/*  -> Edge Runtime (127.0.0.1:9000, the 13 Supabase functions)
                 static files     -> served from disk by Caddy
                 everything else  -> app server  (Node 24, 127.0.0.1:3000)
    Postgres 15 (supabase/postgres image) with pg_cron, pg_net and vault, data in /data/postgres
    s6-overlay starts everything in order: secrets -> postgres -> bootstrap -> services

First boot generates the database password, JWT secret, anon and service-role keys and the cron secret into `/data/config/secrets.env`. Back up the `/data` volume.

## 5. What had to change, and why

| Area | Problem on the Lovable stack | What the container does |
|---|---|---|
| Build target | The Lovable vite config builds for Cloudflare Workers | `NITRO_PRESET=node-server`; the app runs on Node. The build needed no source change. |
| Config in the browser bundle | `VITE_*` values are baked in at build time | Build with placeholders, substitute real values at container start |
| Static files | The Node server announces file sizes from build time, so rewritten JS was cut short and the map stayed blank | Caddy serves static files from disk |
| Backend | Lovable Cloud (managed Supabase) | Postgres, GoTrue, PostgREST and Edge Runtime inside the container |
| Migrations | Written against the live Lovable database | Storage columns added if missing; `cron.unschedule('x')` rewritten to a helper that tolerates missing jobs (a fresh database has none); progress tracked in `public.ww_app_migrations` |
| Cron jobs | Hardcoded project URL, a publishable key and a Lovable preview URL | Rewritten at every boot to local addresses; vault secrets recreated at boot |
| Edge Runtime | Binary needs a newer glibc than the Postgres base image | Ships its own libraries and loader |
| Basemap | A CARTO key was committed in `.env` | Each deployment sets its own `CARTO_API_KEY` |
| Datacenter IPs | CMC and CBIBS data sources refuse cloud IPs | Documented residential relay with `cmc-push.mjs` |
| Repo hygiene | An old `.env` stayed in git history | Sanitized repo without history. The owner should rotate the CARTO key and confirm the old cron secret was rotated. |

## 6. Lovable-specific coupling found in the app

- Migrations contain the Lovable project URL, a publishable key and a Lovable preview URL (cron jobs and vault defaults).
- `vite.config.ts` imports `@lovable.dev/vite-tanstack-config`, which adds the Cloudflare plugin for builds.
- `src/integrations/supabase/previewAuthStorage.ts` brokers sessions to the Lovable editor on Lovable domains. It is harmless elsewhere.
- Error messages say "Connect Supabase in Lovable Cloud".
- Deployed edge functions live in the Lovable dashboard. The repo copies are reference only, so they may differ from what is live.
- Sign-up email relies on Lovable Emails. Self-hosted installs need SMTP or the auto-confirm option.
- The `/api/seed` route is disabled when `NODE_ENV=production`, so a fresh install has no way to load sites except the ingestion adapters.

## 7. Status

Working: image builds in CI; all migrations apply on an empty database; GoTrue, PostgREST, Edge Runtime, the app and Caddy start; the map renders; sign-in works.

Not working or unknown:

- A fresh database has no sites or readings until ingestion runs or data is imported.
- Creating a personal spot on the map does not show a result on the self-hosted build (under investigation).
- The edge runtime logged a wall-clock warning after a cron-triggered function call.
- There is no admin role or admin screen anywhere in the app (searched code, migrations and docs).
- Auth emails need SMTP or `AUTO_CONFIRM=true`.
- arm64 (Oracle Ampere) is not tested.

## 8. Requested feature: admin console

Today whoever holds the database password or service-role key is the only administrator. The app needs a real admin area.

Roles
- `user_roles(user_id, role)` with an enum `app_role` ('admin', 'moderator') and a `has_role(uuid, app_role)` function marked security definer, so policies do not recurse.
- First admin: an `ADMIN_EMAIL` environment variable. On sign-up or sign-in with that email, grant admin if no admin exists.
- Every admin server function must check the role on the server. The existing code already treats UI checks as non-authoritative; follow that pattern with the existing auth middleware.

Screens under `/admin`
- Users: list, disable, promote or demote.
- Sites: search, activate or deactivate, edit, delete, import from CSV or GeoJSON, review user-submitted spots.
- Jobs: list `cron.job` entries with schedule, last run from `cron.job_run_details` and the `ingest_runs` table; run now; enable or disable.
- Data sources: adapter on/off, last success, last error.
- Settings: default map center, zoom and style, site title, disclaimer text, alert sender address.
- Keys: CARTO, Resend and Anthropic keys, shown masked, stored server-side. Environment variables take precedence over stored values.
- Audit log of admin actions.

Settings storage: a `app_settings` key-value table readable by the public for non-secret values (map center) and by admins only for everything else. Secrets belong in vault, not in this table.

## 9. Prompts for Lovable (one concern per prompt)

The project's own workflow notes recommend one concern per prompt, then a layout pass.

1. Schema: "Add `app_role` enum, `user_roles` table, `has_role()` security-definer function and `app_settings` table with RLS. Idempotent migration. No UI changes."
2. Logic: "Add admin-only server functions for users, sites and settings. Check `has_role` on the server for every call. No layout changes."
3. First admin: "Grant the admin role to the user whose email equals the `ADMIN_EMAIL` environment variable when no admin exists."
4. Jobs: "Add server functions that read `cron.job`, `cron.job_run_details` and `ingest_runs` and can trigger an ingestion run. Admin only."
5. UI: "Add `/admin` with Users, Sites, Jobs, Settings and Keys tabs using the existing UI components."
6. Polish: "Check every new page at 390px width. Nothing may be hidden behind the bottom tab bar (84px)."
7. Map settings: "Read the default map center and zoom from `app_settings`, falling back to the current constants."

## 10. Ground rules for edits

- Do not edit auto-generated files under `src/integrations/supabase/` by hand.
- Migrations must be idempotent and must not contain environment-specific URLs or keys. Use settings or vault lookups instead of literals. Guard `cron.unschedule` with an existence check.
- Never commit `.env`, keys or tokens. Each deployment brings its own CARTO, Resend and Anthropic keys.
- Open pull requests; keep container changes in `watervoice` and app changes in the app repo.
