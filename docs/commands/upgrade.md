# ops upgrade

[中文](upgrade.zh-CN.md)

```text
ops upgrade
```

Applies platform changes on the server after a new platform version has been
merged into the instance and synced. Safe to repeat.

## Flow

1. Requires root, loads `ops.conf`.
2. Relinks `/usr/local/bin/ops` to `/opt/ops/platform/bin/ops`.
3. If any app has a `site.caddy`: runs `ops up edge` (recreates the edge if its
   compose file or image changed, regenerates its network override).
4. If `/etc/cron.d/ops` exists: reruns [`ops install-cron`](install-cron.md), so
   changes to the cron or logrotate files take effect.
5. Logs `upgraded to platform <VERSION>`.

It does not restart apps or change `/etc/ops`. Steps beyond this are listed per
version in `CHANGELOG.md`.

## Common usage

The whole upgrade, from your machine:

```bash
git fetch upstream
git merge upstream/main          # read CHANGELOG.md for extra steps
platform/bin/ops lint
git push
scripts/sync.sh myserver
ssh myserver ops upgrade
ssh myserver ops status         # platform version and revision
```

If the new version needs a newer restic (the pinned version in
`bootstrap.sh` changed), also run `sudo /opt/ops/platform/bootstrap.sh --web`.
