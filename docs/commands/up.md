# ops up

[中文](up.zh-CN.md)

```text
ops up <app>
ops up edge
```

Starts an app, or applies changes to it: pulls its images, (re)creates changed
containers, attaches the edge to its network, and reloads Caddy if the app has a
route. Safe to repeat. `ops up edge` starts or updates only the edge Caddy.

## Flow: `ops up <app>`

1. Requires root, loads `ops.conf`.
2. **App exists**: the name must match `^[a-z0-9][a-z0-9-]*$` and
   `apps/<app>/app.conf` must exist.
3. **Backup targets**: loads `app.conf`. `BACKUP_TARGETS` must be set (to
   target names or `none`). Unless it is `none`, `/etc/ops/backup.env` must exist
   and define every listed target.
4. **Resource budget**: sums `cpus` and `mem_limit` of every service of every
   app (and the edge, if any app has a route). Stops if any service lacks
   either, or if the total exceeds `RESOURCE_BUDGET_CPUS` /
   `RESOURCE_BUDGET_MEM`.
5. Creates `/srv/apps/<app>` (700).
6. If the app has `compose.yaml`:
   1. **Secrets**: if `.env.example` exists, `/srv/apps/<app>/.env` must exist
      and give a non-empty value to every key in it.
   2. Creates the network `app-<app>` if missing.
   3. `docker compose pull --quiet`.
   4. **Architecture**: every image must be built for this server's CPU
      (`amd64` or `arm64`); a mismatch stops before anything starts.
   5. `docker compose up -d --remove-orphans`: recreates only containers whose
      configuration or image changed, and removes containers of services that
      are gone.
   6. Rewrites `/var/lib/ops/edge.networks.yaml` and, if the edge is running,
      connects it to `app-<app>` without restarting it.
7. If the app has `site.caddy`: runs [`ops reload-caddy`](reload-caddy.md)
   (validate, then reload; starts the edge if it is not running).
8. Logs `<app> is up`.

Compose commands for an app always use `--project-directory apps/<app>`,
`-f apps/<app>/compose.yaml`, and `--env-file /srv/apps/<app>/.env` (or
`.env.example` when there is no `.env` yet).

## Flow: `ops up edge`

1. Requires root, loads `ops.conf`.
2. Creates the network `app-<app>` of every app with a compose file.
3. Writes `/var/lib/ops/edge.networks.yaml` (joins the edge to every app
   network).
4. `docker compose up -d --remove-orphans` in `platform/edge` with that override.

No app checks, budget check or reload: use it when the edge itself changed or
is not running.

## Failures

| Message | Fix |
|---|---|
| `no such app` | Sync first; the directory must exist in `/opt/ops/apps` |
| `set BACKUP_TARGETS in app.conf` | Add target names or `none` |
| `backup target 'x' is not defined` | Add `TARGET_X_REPOSITORY` to `/etc/ops/backup.env` or fix the name |
| `every service needs cpus and mem_limit` / `exceed the budget` | Add limits, or lower them |
| `needs /srv/apps/<app>/.env` / `has no value for: …` | Create the file from `.env.example` (mode 600) and fill it in |
| `image … is amd64, but this server is arm64` | Pick an image or tag that exists for arm64 |
| `Caddy configuration is invalid` | The containers were updated but the route was not; fix `site.caddy`, sync, `ops reload-caddy` |

## Common usage

```bash
ops up vaultwarden          # after changing its compose.yaml, .env or image tag
ops up umami
ops up edge                 # after an edge change, or if Caddy is not running
for app in umami vaultwarden; do ops up "$app"; done   # every app, e.g. after a rebuild
```

To update an image: change its tag in `compose.yaml`, commit, sync, `ops up <app>`.
