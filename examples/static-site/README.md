# Static site

[中文](README.zh-CN.md)

A site built by its own repository's CI and served by the edge Caddy from
`/srv/www/<site>/current`. Nothing runs in a container and nothing is backed up:
the site can be rebuilt from Git.

1. Copy this directory to `apps/<site>`. In `site.caddy`, replace `static-site`
   with `<site>`, set the domains, and set the hashed asset prefix (`/_astro/`
   for Astro, `/assets/` for Vite).
2. On the server, set `DEPLOY_USER` in `ops.conf` and run
   `bootstrap.sh --web --deploy-key '<CI public key>'`.
3. Copy `deploy.sh` into the site's repository and call it from CI with that
   key: `deploy.sh deploy@<server> <site> dist`.
4. `ops up <site>` loads the route.

Roll back with `ops rollback <site>` (lists releases) and
`ops rollback <site> <release>`.
