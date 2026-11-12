# ops check

[中文](check.zh-CN.md)

```text
ops check
```

Maintains every backup target: removes data no snapshot needs any more, then
verifies the repository and reads back a random 5% of its data. cron runs it
weekly at `CHECK_TIME`, appending to `/var/log/ops/check.log`.

## Flow

1. Requires root, loads `ops.conf` and `/etc/ops/backup.env`.
2. Creates `/var/backups/ops`.
3. **Lock**: takes `flock` on `/var/backups/ops/.lock`, **waiting** for a
   running backup to finish (unlike `ops backup`, which gives up at once).
4. For each target defined in `backup.env` (whether or not any app uses it):
   1. `restic prune`: deletes the data that `restic forget` released during
      the nightly backups.
   2. `restic check --read-data-subset=5%`: checks the repository structure and
      reads back a random 5% of the data packs, so over time most of it gets
      read.
   3. Logs `<target>: ok` or `failed`; a failure does not stop the next target.
   Both wait up to 10 minutes for a repository lock.
5. If any target failed: emails `backup check failed` with the list and exits 1.
   Otherwise logs `check finished`.

## Common usage

```bash
ops check                             # after restoring connectivity to a target, or by hand after a failure email
tail -n 50 /var/log/ops/check.log
```

It can run for a long time on a large repository. Run it in `tmux` or with
`nohup` when doing it by hand.
