# ops rollback

[中文](rollback.zh-CN.md)

```text
ops rollback <site>
ops rollback <site> <release>
```

Lists the releases of a static site, or switches the site back to one of them.
Static sites are published by CI with `deploy.sh` into
`/srv/www/<site>/releases/<release>`, and `/srv/www/<site>/current` points at
the live one; `deploy.sh` keeps the last 5.

## Flow

1. Requires root. Does not read `ops.conf`.
2. Requires `/srv/www/<site>/releases`.
3. **Without a release:** prints where `current` points and lists the releases,
   newest first. Changes nothing.
4. **With a release:** requires `releases/<release>`, creates a new symlink
   `current.next`, and renames it over `current` (`mv -T`), so the switch is
   atomic and Caddy never sees a missing directory. Prints the new target.

No Caddy reload is needed: Caddy serves `/srv/www/<site>/current` and follows
the link on each request. The next CI deploy switches `current` to its new
release again, so fix the site in Git before the next push.

## Common usage

```bash
ops rollback blog                            # list
ops rollback blog 20261110083015-1a2b3c4   # switch back (names are <UTC time>-<commit>)
```
