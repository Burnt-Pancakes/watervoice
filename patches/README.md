Place `*.patch` files here (git diff format, relative to the dc-water-watch repo root). The Dockerfile applies them after cloning the app and before `npm ci`.

Expected first patches: a Node fallback for the `cloudflare:workers` ASSETS binding in `src/lib/routingAssetFetch.server.ts`, and any vite config tweaks needed for the node-server build.
