# ops down

[中文](down.zh-CN.md)

```text
ops down <app>
```

Stops an app and removes its containers and network. **Data is kept**:
`/srv/apps/<app>` and named volumes stay, and the route stays loaded in Caddy
(requests get a 502) until the app directory is removed and Caddy is reloaded.

## Flow

1. Requires root, loads `ops.conf`, checks that the app exists.
2. If the app has `compose.yaml`:
   1. `docker compose down`: stops and removes the containers and the project's
      own networks. Named volumes are kept (no `-v`).
   2. Rewrites `/var/lib/ops/edge.networks.yaml` and disconnects the running
      edge from `app-<app>`.
   3. Removes the network `app-<app>` (ignores errors).
3. Logs that the app is down and that its route stays until removed.

A static site (no compose file) has nothing to stop; the command only logs.

## Common usage

Stop temporarily, then start again:

```bash
ops down umami
ops up umami
```

Remove an app for good:

```bash
ops backup vaultwarden                 # a last backup
ops down vaultwarden
# your machine: git rm -r apps/vaultwarden, commit, scripts/sync.sh myserver
ops reload-caddy                       # drops the route
# once sure: rm -rf /srv/apps/vaultwarden, docker volume rm <volumes>
```

Move an app to another server: `ops backup <app>` and `ops down <app>` here,
then [`ops restore <app> --host <old OPS_HOST>`](restore.md) on the new server.
