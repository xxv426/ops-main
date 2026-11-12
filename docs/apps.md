# Writing an app

An app is a directory under `apps/` in the instance repository. ops reads only
what is listed here.

```text
apps/<app>/
├── app.conf          required: what ops needs to know
├── README.md         required: what it is and anything unusual about it
├── compose.yaml      the containers (a static site has none)
├── site.caddy        the public route (apps without public access have none)
├── .env.example      the secrets it needs, without values
├── backup-hook.sh    required when backups are on: write consistent data to $STAGE
├── restore-hook.sh   required when backups are on: put $RESTORE_DIR back
└── verify-hook.sh    optional: check a restored copy for `ops restore-test`
```

`platform/bin/ops new <app>` creates one from `platform/templates/app`. The
`examples/` directory has complete apps to copy.

## app.conf

```bash
APP_DOMAINS="vault.example.com"
HEALTH_URL="https://vault.example.com/alive"   # checked after a restore and by your monitor
BACKUP_TARGETS="remote b2"                      # required: names from /etc/ops/backup.env, or none
BACKUP_KEEP="--keep-daily 14 --keep-weekly 8 --keep-monthly 12"
BACKUP_EXCLUDE=""                               # restic --exclude patterns, space-separated
```

There is no default for `BACKUP_TARGETS`. `ops up` refuses an app without it,
and refuses a target the server has not defined.

Suggested levels:

| Data | `BACKUP_TARGETS` | Keep |
|---|---|---|
| Lost for good if lost | every target, one off-site | 14 days, 8 weeks, 12 months |
| Painful to rebuild | the nearby target | 7 days, 4 weeks, 6 months |
| Re-downloadable or rebuilt from Git | `none` | — |

## compose.yaml

- `name:` is the app name.
- Data lives under `/srv/apps/<app>/` (bind mounts) or in named volumes.
- Secrets come from `/srv/apps/<app>/.env`. ops passes it to Compose for both
  `${VAR}` interpolation and `env_file`. Use `required: false` on `env_file` so
  `ops lint` works without it; `ops up` refuses to start until every key from
  `.env.example` has a value.
- Public traffic goes through the edge only: join the external network
  `app-<app>` and publish no public port. Bind admin ports to `127.0.0.1`.
- Put databases on an `internal: true` network.
- Every service sets `cpus` and `mem_limit`; the total must fit `ops.conf`.
- Pin every image to a version. It must exist for the server's CPU
  architecture; `ops up` checks.

## site.caddy

Only this app's site blocks. Upstreams are Compose service names. Snippets from
`platform/edge/caddy/Caddyfile` are available:

- `import security_headers`: HSTS, nosniff, referrer policy, no `Server` header.
- `import static_site <site> <hashed prefix>`: serves `/srv/www/<site>/current`
  with precompressed files and long caching for hashed assets.

Add the DNS record and wait until it resolves before the first `ops up`, or
Let's Encrypt validation fails repeatedly and rate-limits the domain.

## Hooks

Hooks are sourced by ops in a subshell with `set -euo pipefail`. They can use:

| Name | Value |
|---|---|
| `$APP` | app name |
| `$APP_DIR` | the app's directory in `/opt/ops/apps` (also the working directory) |
| `$APP_DATA` | `/srv/apps/<app>` |
| `$STAGE` | backup hook: empty directory to write into |
| `$RESTORE_DIR` | restore and verify hooks: the files the backup hook wrote |
| `compose ...` | `docker compose` for this app |

ops itself adds `/srv/apps/<app>/.env` to every backup and restores it when it is
missing (or with `--restore-env`), so hooks never handle it.

- **backup-hook.sh**: write a consistent copy. Use the database's own tools
  (`pg_dump`, `sqlite3 .backup`), never copy live database files. Exit non-zero
  on any doubt.
- **restore-hook.sh**: runs with the app stopped. Start only what it needs
  (`compose up -d db`), put the data back, and leave starting the app to ops.
- **verify-hook.sh**: inspect the restored copy without touching the running
  app, for example `PRAGMA integrity_check` or `gunzip -t`.
