# ops command reference

[中文](README.zh-CN.md)

One page per command: what it does step by step (taken from the code in
`platform/`), what it reads and writes, how it fails, and the forms used day to
day. Examples use an SSH host `myserver` and the example apps `vaultwarden` and
`umami` (`examples/`), backing up to the targets `remote` and `b2` from
`platform/templates/backup.env.example`.

## Where each command runs

| Command | Runs on | Root | Page |
|---|---|---|---|
| `scripts/sync.sh <host>` | your machine | no | [sync](sync.md) |
| `bootstrap.sh` | server, once | yes | [bootstrap](bootstrap.md) |
| `ops init` | server, once | yes | [init](init.md) |
| `ops install-cron` | server | yes | [install-cron](install-cron.md) |
| `ops backup-client add` | backup server | yes | [backup-client](backup-client.md) |
| `ops up <app>\|edge` | server | yes | [up](up.md) |
| `ops down <app>` | server | yes | [down](down.md) |
| `ops logs <app>\|edge` | server | docker access | [logs](logs.md) |
| `ops reload-caddy` | server | yes | [reload-caddy](reload-caddy.md) |
| `ops status [--usage]` | server | docker access; root for `--usage` | [status](status.md) |
| `ops rollback <site> [release]` | server | yes | [rollback](rollback.md) |
| `platform/bin/ops new <app>` | your machine | no | [new](new.md) |
| `ops backup <app>\|--all` | server (also cron) | yes | [backup](backup.md) |
| `ops check` | server (also cron) | yes | [check](check.md) |
| `ops restore <app>` | server | yes | [restore](restore.md) |
| `ops restore-test <app>` | server | yes | [restore-test](restore-test.md) |
| `ops alert-test` | server | yes | [alert-test](alert-test.md) |
| `platform/bin/ops lint` | your machine, CI, server (by sync) | no | [lint](lint.md) |
| `ops upgrade` | server | yes | [upgrade](upgrade.md) |
| `ops version` | anywhere | no | below |
| `ops` / `ops help` | anywhere | no | below |

`ops version` prints `VERSION` (the platform version, e.g. `0.1.0`). `ops`,
`ops help`, `-h` and `--help` print the usage; an unknown command prints it to
stderr and exits 1.

## How a command starts

Every `ops` call goes through `platform/bin/ops`:

1. Resolves its own path through the `/usr/local/bin/ops` symlink and sets
   `OPS_ROOT` to the repository root (normally `/opt/ops`) unless already set.
2. Sources `platform/lib/{common,edge,apps,backup,alert,init,lint}.sh`.
3. Dispatches on the first argument to a `cmd_*` function.

Most commands then call `require_root` and `load_ops_conf`, which sources
`ops.conf`, requires `OPS_HOST`, `RESOURCE_BUDGET_CPUS` and
`RESOURCE_BUDGET_MEM`, detects `OPS_ARCH` from `uname -m` (`amd64` or `arm64`)
and fills in the defaults for `BACKUP_TIME`, `CHECK_TIME` and `DEPLOY_USER`.

Paths can be overridden with environment variables, which is how `lint` runs in
CI and how `sync.sh` lints the new files before installing them:

| Variable | Default |
|---|---|
| `OPS_ROOT` | the repository holding `platform/bin/ops` |
| `OPS_CONF` | `$OPS_ROOT/ops.conf` |
| `OPS_APPS_DIR` | `$OPS_ROOT/apps` |
| `OPS_ETC` | `/etc/ops` |
| `OPS_STATE` | `/var/lib/ops` |
| `OPS_LOG_DIR` | `/var/log/ops` |
| `OPS_STAGE_ROOT` | `/var/backups/ops` |
| `OPS_DATA_ROOT` | `/srv/apps` |
| `OPS_WWW_ROOT` | `/srv/www` |

## Day-to-day sequences

Change an app's compose file or `.env`:

```bash
git commit -am "..." && scripts/sync.sh myserver     # your machine
ssh myserver ops up vaultwarden                     # server
```

Change only a route (`site.caddy`):

```bash
git commit -am "..." && scripts/sync.sh myserver
ssh myserver ops reload-caddy
```

Look at a server:

```bash
ssh myserver ops status
ssh myserver ops logs vaultwarden -f
ssh myserver tail -n 50 /var/log/ops/backup.log
```

Upgrade the platform:

```bash
git fetch upstream && git merge upstream/main         # read CHANGELOG.md
git push && scripts/sync.sh myserver
ssh myserver ops upgrade
```

Quarterly drill:

```bash
ssh myserver ops restore-test vaultwarden
ssh myserver ops restore-test umami --from b2
```
