# syntax=docker/dockerfile:1.7
# WaterWatch all-in-one: Postgres (pg_cron/pg_net/vault) + GoTrue + PostgREST + Edge Runtime + app + Caddy, supervised by s6-overlay.
# UNTESTED SCAFFOLD: pin every tag below to the versions in Supabase's current docker-compose.yml.
ARG PG_IMAGE=supabase/postgres:15.8.1.085
ARG AUTH_IMAGE=supabase/gotrue:v2.177.0
ARG POSTGREST_IMAGE=postgrest/postgrest:v12.2.12
ARG EDGE_IMAGE=supabase/edge-runtime:v1.69.6
ARG CADDY_IMAGE=caddy:2.8

FROM ${AUTH_IMAGE} AS auth
FROM ${POSTGREST_IMAGE} AS postgrest
FROM ${EDGE_IMAGE} AS edge
FROM ${CADDY_IMAGE} AS caddy

# ---- app build (placeholders are swapped for real values at container start) ----
FROM node:24-bookworm AS build
ARG APP_REPO=https://github.com/Burnt-Pancakes/dc-water-watch.git
ARG APP_REF=main
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git init -q . && git remote add origin ${APP_REPO} && git fetch --depth 1 origin ${APP_REF} && git checkout -q FETCH_HEAD
COPY patches/ /patches/
RUN for p in /patches/*.patch; do [ -e "$p" ] || continue; git apply "$p"; done
RUN npm ci --ignore-scripts
ENV VITE_SUPABASE_URL=__WW_SUPABASE_URL__ \
    VITE_SUPABASE_PUBLISHABLE_KEY=__WW_ANON_KEY__ \
    VITE_SUPABASE_ANON_KEY=__WW_ANON_KEY__ \
    NITRO_PRESET=node-server
RUN npm run build
RUN mkdir /out && for d in .output dist; do [ -d "$d" ] && cp -a "$d" /out/ || true; done && ls -la /out

# ---- final image ----
FROM ${PG_IMAGE}
ARG TARGETARCH
ARG S6_VERSION=3.2.0.2
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl xz-utils ca-certificates && rm -rf /var/lib/apt/lists/*
RUN case "$TARGETARCH" in arm64) A=aarch64;; *) A=x86_64;; esac; \
    curl -fsSL https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-noarch.tar.xz | tar -C / -Jxp && \
    curl -fsSL https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-${A}.tar.xz | tar -C / -Jxp

COPY --from=build /usr/local/bin/node /usr/local/bin/node
COPY --from=auth /usr/local/bin/auth /opt/bin/gotrue
COPY --from=auth /usr/local/etc/auth/migrations /opt/gotrue-migrations
COPY --from=postgrest /bin/postgrest /opt/bin/postgrest
COPY --from=edge /usr/local/bin/edge-runtime /opt/bin/edge-runtime
COPY --from=caddy /usr/bin/caddy /opt/bin/caddy

COPY --from=build /out/ /opt/app-dist/
COPY --from=build /src/supabase/functions /opt/functions
COPY --from=build /src/supabase/migrations /opt/migrations
COPY docker/functions-main /opt/functions/main
COPY docker/sql /opt/ww/sql
COPY docker/gen-secrets.mjs /opt/ww/gen-secrets.mjs
COPY docker/Caddyfile /etc/caddy/Caddyfile
COPY docker/s6-overlay/ /etc/s6-overlay/
RUN chmod +x /etc/s6-overlay/scripts/*.sh /etc/s6-overlay/s6-rc.d/*/run 2>/dev/null || true

ENV S6_KEEP_ENV=1 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=300000
VOLUME /data
EXPOSE 80 443
ENTRYPOINT ["/init"]
