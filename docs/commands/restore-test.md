# ops restore-test

[中文](restore-test.zh-CN.md)

```text
ops restore-test <app> [--from <target>] [--snapshot <id>] [--host <name>]
```

A restore drill that touches nothing running: restores a snapshot to a
temporary directory, lists its files, and runs the app's `verify-hook.sh` if
it has one. Do it for each app every quarter, and for each target now and then.

The options are the same as for [`ops restore`](restore.md) (`--restore-env` is
accepted and ignored).

## Flow

1. Requires root, loads `ops.conf` and `/etc/ops/backup.env`.
2. Parses the options and picks the target and snapshot exactly as
   `ops restore` does.
3. Restores the snapshot into `/var/backups/ops/restore-<app>.XXXXXX`, deleted
   when the command exits.
4. Prints every file in the snapshot with its size, sorted.
5. If `apps/<app>/verify-hook.sh` exists, runs it with `RESTORE_DIR`; it checks
   the restored copy without touching the running app (for example
   `PRAGMA integrity_check` on a SQLite file, `gunzip -t` on a dump). A failure
   stops with `verify-hook.sh failed`.
6. Logs `<app>: restore test passed (<target>)`.

Without a verify hook the test only proves the snapshot can be read and
restored.

## Common usage

```bash
ops restore-test vaultwarden                 # newest snapshot, first target (remote)
ops restore-test vaultwarden --from b2       # the off-site copy
ops restore-test umami
ops restore-test umami --from b2
```

The examples' verify hooks: Vaultwarden runs `PRAGMA integrity_check`, prints
the number of users and items, and requires `rsa_key.pem`; Umami tests its dump
with `gunzip -t`, requires the dump's end marker, and counts its tables.
