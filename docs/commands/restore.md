# ops restore

[中文](restore.zh-CN.md)

```text
ops restore <app> [--from <target>] [--snapshot <id>] [--host <name>] [--restore-env]
```

Replaces an app's data with a snapshot and starts it again. Without options it
restores the newest snapshot of this host from the app's first target.

| Option | Default | Use |
|---|---|---|
| `--from <target>` | first name in `BACKUP_TARGETS` | Restore from another target, e.g. when the first is unreachable |
| `--snapshot <id>` | the newest snapshot of the app from `--host` | A specific point in time (`restic snapshots` gives ids) |
| `--host <name>` | this server's `OPS_HOST` | Restore another server's backup: moving an app, or a rebuilt server with a new `OPS_HOST` |
| `--restore-env` | off | Also replace an existing `/srv/apps/<app>/.env` with the backed-up one |

## Flow

1. Requires root, loads `ops.conf` and `/etc/ops/backup.env`.
2. Parses the options; checks that the app exists, that the target is set (not
   `none`) and defined in `backup.env`.
3. **Finds the snapshot**: for `latest`, lists the snapshots with
   `--host <host> --tag <app>` and takes the newest; stops if there is none.
   Reads the snapshot's backed-up path (the staging directory it was taken
   from).
4. **Restores to a temporary directory** `/var/backups/ops/restore-<app>.XXXXXX`
   with `restic restore`. It is deleted when the command exits, whether or not
   it succeeds. `RESTORE_DIR` is the backed-up files inside it.
5. Creates `/srv/apps/<app>`.
6. **Secrets**: if the snapshot has `.ops/env`, installs it as
   `/srv/apps/<app>/.env` (600) when there is no `.env` yet or with
   `--restore-env`. Otherwise keeps the current one and says so.
7. If the app has `compose.yaml`: `docker compose down` (stops the app; named
   volumes are kept) and makes sure the network `app-<app>` exists.
8. **Runs `restore-hook.sh`** with `RESTORE_DIR`. The hook starts only what it
   needs (for example `compose up -d db`), puts the data back, and leaves
   starting the app to ops. If it fails, stops with
   `restore-hook.sh failed` and the app stays down.
9. Runs [`ops up <app>`](up.md): every check, pull, start, edge attach and Caddy
   reload.
10. **Health check**: if `HEALTH_URL` is set, requests it every 2 seconds for up
    to 60 seconds. For apps with a route and an `https://` URL, the request goes
    to `127.0.0.1` with the right host name (some clouds cannot reach their own
    public IP). A failure is only a warning.
11. Logs `<app> restored`.

The apps' hooks decide what happens to the current data. The Vaultwarden
example's hook keeps the previous data in `data.before-restore-*` until you
delete it.

## Common usage

```bash
ops restore vaultwarden                                 # newest snapshot from remote
ops restore vaultwarden --from b2                       # remote unreachable
ops restore vaultwarden --snapshot 4f9c2a1b             # a specific point in time
ops restore umami --host old --restore-env                # on a new server: bring an app over, with its .env
```

Before restoring, find the snapshot you want:

```bash
set -a; . /etc/ops/backup.env; set +a
RESTIC_REPOSITORY=$TARGET_REMOTE_REPOSITORY restic snapshots --tag vaultwarden
```

Rebuild a whole server: sync, `bootstrap.sh`, put the old restic password in
`/etc/ops/restic-password`, restore `backup.env` and `alert.env` from the
password manager, `ops init`, then `ops restore <app>` for each app,
`ops install-cron`, and check DNS.
