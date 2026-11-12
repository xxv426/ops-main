# ops backup

[中文](backup.zh-CN.md)

```text
ops backup <app>
ops backup --all
```

Backs up one app, or every app, to each of its targets now. cron runs
`ops backup --all` nightly at `BACKUP_TIME`, appending to
`/var/log/ops/backup.log`.

## Flow

1. Requires root, loads `ops.conf` and `/etc/ops/backup.env` (exports
   `RESTIC_PASSWORD_FILE`).
2. Chooses the apps: every directory with an `app.conf` for `--all`, or the
   one named (which must exist).
3. Creates `/var/backups/ops` (700) and `/var/lib/ops/backup`.
4. **Lock**: takes `flock -n` on `/var/backups/ops/.lock`. If another backup
   or check holds it, stops at once with `another backup or check is running`.
5. For each app, in turn:
   1. Loads `app.conf`. Empty `BACKUP_TARGETS`: warns and counts it as a
      failure. `none`: skips the app silently.
   2. Empties and creates the staging directory `/var/backups/ops/<app>` and
      `<stage>/.ops`.
   3. Runs `backup-hook.sh` with `STAGE=<stage>` (in a subshell, `set -euo
      pipefail`, working directory `apps/<app>`, with `$APP`, `$APP_DIR`,
      `$APP_DATA` and a `compose` function). The hook writes a consistent copy,
      such as `pg_dump` output or a SQLite online backup. If it fails, the app
      is marked `hook` failed and no target is touched.
   4. Copies `/srv/apps/<app>/.env` to `<stage>/.ops/env` (600), so a restore
      can bring the secrets back.
   5. For each target in `BACKUP_TARGETS`:
      - not defined in `backup.env`: marked failed;
      - otherwise, with only that target's `TARGET_<NAME>_*` variables exported:
        `restic backup --host <OPS_HOST> --tag <app> [--exclude …] <stage>`,
        then `restic forget --tag <app> --group-by tags <BACKUP_KEEP>` (marks
        old snapshots; the data is pruned by the weekly `ops check`). Both wait
        up to 10 minutes for a repository lock.
      - logs `<app> -> <target>: ok` or `failed`. One target failing does not
        stop the others.
   6. Deletes the staging directory.
   7. Writes `/var/lib/ops/backup/<app>.status` (`<UTC time> ok` or
      `<UTC time> FAILED: <targets>`), shown by `ops status`.
   8. Sends a heartbeat if `HEARTBEAT_URL` is set in `alert.env`, with
      `{host}`, `{app}` and `{success}` (`true`/`false`) filled in, and
      `HEARTBEAT_TOKEN` as a bearer token.
6. If any app failed: emails `backup failed` with one line per failed app, then
   exits 1 with `backup finished with failures`. Otherwise logs
   `backup finished`.

Each target is backed up directly from the staging directory, never copied from
another target, so one damaged repository cannot spread to the other.

## Files

| Reads | Writes |
|---|---|
| `apps/<app>/app.conf`, the hooks, `/srv/apps/<app>/`, `/etc/ops/backup.env`, `/etc/ops/alert.env` | restic repositories, `/var/backups/ops/<app>/` (temporary), `/var/lib/ops/backup/<app>.status` |

## Common usage

```bash
ops backup vaultwarden            # before a risky change, an upgrade, or removing the app
ops backup --all                  # after setting up a server, or to retry a failed night
tail -n 50 /var/log/ops/backup.log
ops status                        # LAST BACKUP column
```

Check what is in a repository by hand (load the target's variables first):

```bash
set -a; . /etc/ops/backup.env; set +a
RESTIC_REPOSITORY=$TARGET_REMOTE_REPOSITORY restic snapshots --tag vaultwarden
```

For `b2`, also export `AWS_ACCESS_KEY_ID=$TARGET_B2_AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY=$TARGET_B2_AWS_SECRET_ACCESS_KEY`.
