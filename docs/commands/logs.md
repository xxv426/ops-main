# ops logs

[中文](logs.zh-CN.md)

```text
ops logs <app>|edge [docker compose logs options] [service…]
```

Shows the last 100 lines of an app's containers (or the edge Caddy's). Extra
arguments go straight to `docker compose logs`.

## Flow

1. Does not require root or `ops.conf`; needs access to Docker (root or the
   `docker` group).
2. `edge`: `docker compose logs --tail 100 <args>` in `platform/edge`.
3. Otherwise checks that the app exists, then
   `docker compose logs --tail 100 <args>` for the app, with the same project
   directory and env file as `ops up`.

ops's own logs are separate: `/var/log/ops/backup.log` and
`/var/log/ops/check.log` (written by cron).

## Common usage

```bash
ops logs vaultwarden                 # last 100 lines
ops logs vaultwarden -f              # follow
ops logs umami umami-db               # one service of a multi-service app
ops logs umami --since 1h umami
ops logs edge -f                     # Caddy: certificates, upstream errors
ops logs edge --tail 500             # a later --tail wins over the default 100
```
