# ops init

[中文](init.zh-CN.md)

```text
ops init [--generate-password] [--init-missing]
```

Creates and checks everything under `/etc/ops`: the restic password, the backup
targets, and the alert settings. Idempotent: each run creates what is missing,
**stops at the first file you need to fill in**, and once everything is in place
checks every backup target and sends a test email. Run it repeatedly until it
says `init finished`.

| Option | Effect |
|---|---|
| `--generate-password` | Create a new random restic password if none exists |
| `--init-missing` | Create (`restic init`) target repositories that do not exist yet |

## Flow

1. Requires root, loads `ops.conf`, parses the options (unknown ones stop it).
2. Creates `/etc/ops` (700), `/var/lib/ops` and `/var/log/ops` (755),
   `/var/backups/ops` and `/srv/apps` (700).
3. **No backups at all?** If every app has `BACKUP_TARGETS=none`, skips restic
   entirely: creates `alert.env` from the template if missing (and stops so you
   can fill it in), then sends a test alert and finishes.
4. **restic password.** If `/etc/ops/restic-password` is missing or empty:
   - with `--generate-password`, writes 32 random bytes as hex (`openssl rand
     -hex 32`, umask 077) and tells you to save a copy now;
   - otherwise stops and asks you to write an existing password there.

   Then sets the file to mode 600.
5. **backup.env.** If `/etc/ops/backup.env` is missing, installs
   `platform/templates/backup.env.example` (mode 600) and stops so you can fill
   it in.
6. Loads `backup.env` (requires `RESTIC_PASSWORD_FILE` to be set and readable)
   and lists the targets (`TARGET_<NAME>_REPOSITORY`). Warns if there are none.
7. **Each target:** `restic cat config` with that target's variables.
   - Reachable: logs `repository is reachable`.
   - Not reachable and `--init-missing`: `restic init`, logs `repository created`.
   - Not reachable otherwise: stops. Either `backup.env` is wrong, or the
     repository does not exist yet.
8. **alert.env.** If `/etc/ops/alert.env` is missing, installs the template and
   stops so you can fill it in. Sets it to mode 600.
9. Sends a test alert (`ops alert-test`). If it fails, stops with
   `fix alert.env, then run ops init again`.
10. Logs `init finished. Next: ops up <app> for each app, then ops install-cron`.

## Files

| Reads | Writes |
|---|---|
| `ops.conf`, `apps/*/app.conf`, the targets' repositories | `/etc/ops/restic-password`, `/etc/ops/backup.env`, `/etc/ops/alert.env` (from templates), new restic repositories |

## Common usage

A new server, step by step:

```bash
ops init --generate-password    # creates the password, then backup.env; stops
vi /etc/ops/backup.env          # define TARGET_REMOTE_* and TARGET_B2_*
ops init --init-missing         # checks/creates the repositories, creates alert.env; stops
vi /etc/ops/alert.env           # SMTP settings, heartbeat URL
ops init                        # checks everything, sends a test email
```

Reusing an existing password (moving or rebuilding a server):

```bash
install -m 600 /dev/stdin /etc/ops/restic-password   # paste the password, then Ctrl-D
ops init
```

Later, after adding a target to `backup.env`:

```bash
ops init --init-missing
```
