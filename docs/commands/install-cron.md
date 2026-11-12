# ops install-cron

[中文](install-cron.zh-CN.md)

```text
ops install-cron
```

Schedules the nightly backup and the weekly check from `ops.conf`, and sets up
rotation of their logs. Run it once after the apps are up, and again after
changing `BACKUP_TIME` or `CHECK_TIME`. `ops upgrade` reruns it when
`/etc/cron.d/ops` exists.

## Flow

1. Requires root, loads `ops.conf` (`BACKUP_TIME` defaults to `30 19 * * *`,
   `CHECK_TIME` to `0 21 * * 0`).
2. Creates `/var/log/ops`.
3. Overwrites `/etc/cron.d/ops` (mode 644):

   ```text
   SHELL=/bin/bash
   PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
   <BACKUP_TIME> root /opt/ops/platform/bin/ops backup --all >>/var/log/ops/backup.log 2>&1
   <CHECK_TIME>  root /opt/ops/platform/bin/ops check >>/var/log/ops/check.log 2>&1
   ```

4. Overwrites `/etc/logrotate.d/ops`: `/var/log/ops/*.log` rotated monthly,
   12 kept, compressed.
5. Logs the schedule and the server's time zone. cron uses the server's time
   zone, usually UTC.

## Files

| Reads | Writes |
|---|---|
| `ops.conf` | `/etc/cron.d/ops`, `/etc/logrotate.d/ops` |

## Common usage

```bash
ops install-cron
cat /etc/cron.d/ops                        # what is scheduled
tail -n 50 /var/log/ops/backup.log         # what last night's run did
tail -n 50 /var/log/ops/check.log
```

The defaults are 19:30 daily and 21:00 on Sundays, server time. To run at
03:30 Beijing time on a UTC server, set `BACKUP_TIME="30 19 * * *"`.
