# ops reload-caddy

[中文](reload-caddy.zh-CN.md)

```text
ops reload-caddy
```

Validates the Caddy configuration and, only if it is valid, reloads it in the
running edge without dropping connections. Use it after changing a
`site.caddy` (or removing an app) and syncing.

Why not `caddy reload` directly: a failed reload leaves the broken file on disk,
and the next restart of the edge would refuse to start and take every site down.
Validating first means a broken file is noticed at once.

## Flow

1. Requires root, loads `ops.conf`.
2. **Edge not running?** If any app has a `site.caddy`, starts the edge
   ([`ops up edge`](up.md)) and returns; otherwise returns doing nothing.
3. `caddy validate --config /etc/caddy/Caddyfile` inside the edge container.
   The Caddyfile imports every `/etc/ops-apps/*/site.caddy`, which is
   `/opt/ops/apps` mounted read-only, so it validates exactly what was synced.
   On failure stops with `Caddy configuration is invalid; nothing was reloaded`;
   the running configuration stays as it was.
4. `caddy reload` with the same file.
5. Logs `Caddy reloaded`.

`ops up <app>` runs these same steps for apps with a `site.caddy`.
`scripts/sync.sh` already ran `ops lint`, which validates the configuration in a
throwaway container, so a failure here is rare.

## Common usage

```bash
ops reload-caddy                 # after a route change: commit, sync, then this
ops logs edge --since 5m         # certificate issuance for a new domain
```

For a new domain, add the DNS record and wait until it resolves before the
first reload, or Let's Encrypt validation fails repeatedly and rate-limits the
domain.
