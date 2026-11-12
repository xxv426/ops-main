# ops new

[中文](new.zh-CN.md)

```text
platform/bin/ops new <app>
```

Creates `apps/<app>` from `platform/templates/app`. Run it **in your local
checkout** of the instance repository, not on the server: the server's
`/opt/ops` is replaced on every sync.

## Flow

1. Does not require root or `ops.conf`.
2. The name must match `^[a-z0-9][a-z0-9-]*$`, and `apps/<app>` must not exist.
3. Copies `platform/templates/app` to `apps/<app>`.
4. Replaces `__APP__` with the app name in every file.
5. Prints `Created apps/<app>. Fill in every file, then commit and sync.`

The template contains `app.conf`, `compose.yaml`, `site.caddy`, `.env.example`,
`backup-hook.sh`, `restore-hook.sh`, `verify-hook.sh` and `README.md`. See
[docs/apps.md](../apps.md) for what goes in each. Delete what the app does not
need (`site.caddy` for an app without public access, the compose file for a
static site, the hooks if `BACKUP_TARGETS=none`).

## Common usage

```bash
platform/bin/ops new gitea                  # from the template
cp -r examples/umami apps/umami             # or start from a complete example
platform/bin/ops lint                       # check it before committing
git add apps/gitea && git commit -m "Add gitea" && scripts/sync.sh myserver
ssh myserver ops up gitea                  # after creating /srv/apps/gitea/.env and DNS
```
