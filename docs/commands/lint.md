# ops lint

[中文](lint.zh-CN.md)

```text
platform/bin/ops lint
```

Static checks of the instance repository. Needs Docker and jq but not root, so
it runs on your machine, in CI (`.github/workflows/lint.yml`, on every push), and
on the server inside `scripts/sync.sh` before the new files are installed.

## Flow

1. Loads `ops.conf`, lists the apps.
2. Warns if `ops.conf` still has an `OPS_ARCH=` line (it is detected now).
3. For each app (each problem is counted; the lint continues):
   - the name uses lowercase letters, digits and hyphens;
   - `README.md` exists;
   - `BACKUP_TARGETS` is set; unless it is `none`, `BACKUP_KEEP` is set and
     `backup-hook.sh` and `restore-hook.sh` exist;
   - if there is a `compose.yaml`, `docker compose config` succeeds, and:
     - the project `name:` is the app name;
     - an app with `site.caddy` joins the external network `app-<app>`;
     - no port is published on all interfaces (bind to `127.0.0.1` or a private
       IP);
     - every image has a version tag other than `latest`.
4. **Resource budget**: every service has `cpus` and `mem_limit`, and the total
   (edge included) fits the budget in `ops.conf`. This check stops the lint at
   once if a service lacks limits.
5. **Caddy**: if any app has a route, validates the whole configuration in a
   throwaway container of the edge's Caddy image, with `platform/edge/caddy` and
   `apps/` mounted read-only.
6. **shellcheck** (if installed) on every `*.sh` under `platform/`, `scripts/`
   and `apps/`, and on `platform/bin/ops`, at warning level.
7. Exits 1 with `<n> problem(s) found`, or prints `lint passed`.

## Common usage

```bash
platform/bin/ops lint                                         # before committing
OPS_CONF=ops.conf.example OPS_APPS_DIR=examples platform/bin/ops lint   # lint the examples, as the starter's CI does
```

On Windows run it in Git Bash with Docker Desktop running. The first run pulls
the Caddy image.
