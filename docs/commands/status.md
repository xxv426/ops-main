# ops status

[中文](status.zh-CN.md)

```text
ops status [--usage]
```

A one-screen summary of the server: platform version and synced commit, each
app's running containers and last backup, and the resource budget. `--usage`
adds the size of each backup repository and the snapshot count per app.

## Flow

1. Loads `ops.conf`. Does not call `require_root`, but needs Docker access, and
   `--usage` needs to read `/etc/ops` (so in practice run it as root).
2. Prints the header: `OPS_HOST`, detected architecture, `VERSION`, and
   `/opt/ops/.revision` (the commit `sync.sh` installed, or `unknown`).
3. For each app, a row:

   | Column | Source |
   |---|---|
   | `APP` | directory name |
   | `CONTAINERS` | `running/defined` from `docker compose ps --status running` and `config --services` (services behind a profile are not counted); `static` for apps without compose |
   | `LAST BACKUP` | `/var/lib/ops/backup/<app>.status`, written by `ops backup`: `<UTC time> ok` or `<UTC time> FAILED: <targets>`; `-` if never |
   | `TARGETS` | `BACKUP_TARGETS` from `app.conf` |

4. Prints the resource total against the budget (report only, never fails).
5. With `--usage`, for each target in `backup.env`: the raw data size
   (`restic stats --mode raw-data`), then for each app using that target, its
   number of snapshots. A target that cannot be reached shows `unavailable`.

## Common usage

```bash
ops status                       # daily glance; also from your machine:
ssh myserver ops status
ops status --usage               # monthly: repository growth (slow; talks to every target)
```

Example (times and commit are illustrative):

```text
host: web1 (arm64)  platform: 0.1.0  revision: 65d6393 synced 2026-11-12T08:00:00Z

APP              CONTAINERS LAST BACKUP                              TARGETS
umami            2/2        2026-11-11T19:30:40Z ok                  remote b2
vaultwarden      1/1        2026-11-11T19:31:02Z ok                  remote b2

limits: 1.25 CPU, 1.8 GiB  budget: 2 CPU, 12.0 GiB
```
