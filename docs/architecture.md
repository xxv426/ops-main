# Architecture

## Starter and instances

| | What it holds | Changes when |
|---|---|---|
| **ops-starter** | `platform/` (the `ops` command, edge, backup, alerts, bootstrap), templates, examples, docs | The platform improves |
| **Instance repository** (one per server) | Everything from the starter, plus `ops.conf` and `apps/` | That server's apps change |

An instance never edits `platform/`. It keeps the starter as the `upstream`
remote, so `git merge upstream/main` brings platform updates without conflicts.
Create instances by cloning, not with GitHub's "Use this template", which drops
the shared history.

## Three kinds of state

| Kind | Where | Comes from | Backed up |
|---|---|---|---|
| Configuration | `/opt/ops` | The instance repository | No: Git is the backup |
| Data | `/srv/apps/<app>/`, named volumes | The apps | As each app declares |
| Built files | `/srv/www/<site>/` | CI | No: rebuilt from Git |
| Runtime | Docker containers and networks | Configuration and data | No |

Keeping them apart is what makes the rest simple:

- `scripts/sync.sh` replaces `/opt/ops` wholesale with `rsync --delete`. No
  exclude list is needed, so it can never delete data.
- Backups, moves and rebuilds only have to think about `/srv/apps`.
- CI writes `/srv/www` as an unprivileged user that cannot read any app's secrets.

Server-specific settings that are not secret go in `ops.conf` (committed).
Secrets go in `/etc/ops/` (never committed): the restic password, backup targets
and SMTP.

## Traffic

```text
browser ─► DNS ─► server:443 ─► edge Caddy ─► app-<app> network ─► app
```

- The edge Caddy is the only container that publishes 80/443. It loads every
  `apps/*/site.caddy` (mounted at `/etc/ops-apps`) and static files from
  `/srv/www`.
- Each app with a compose file has its own network, `app-<app>`, created by
  `ops up` outside any Compose project. Only the edge joins all of them, so a
  compromised app cannot reach another. ops writes a Compose override in
  `/var/lib/ops` that attaches the edge to each network, and attaches a running
  edge without restarting it.
- `ops reload-caddy` validates the configuration before reloading. A plain
  `caddy reload` that fails leaves the bad file on disk, and the next restart
  would take every site down.

## Backups

Each app declares what to back up (its hooks) and where (`BACKUP_TARGETS`). The
server defines the targets in `/etc/ops/backup.env`:

```bash
TARGET_<NAME>_REPOSITORY=<any restic repository>
TARGET_<NAME>_<VAR>=<value>      # exported as <VAR> only while restic uses <name>
```

Nightly, `ops backup --all` takes each app in turn: run its backup hook into a
staging directory, add its `.env`, then for each target `restic backup --host
<OPS_HOST> --tag <app>` and `restic forget --group-by tags` with the app's
retention. One app or target failing does not stop the others. Failures send an
email; every app's result can also go to a heartbeat URL.

Weekly, `ops check` prunes each target and reads back a different 5% of it.

Design choices:

- **Each target is backed up directly**, not copied from another target, so a
  damaged repository cannot spread to the other.
- **One repository per server per target.** On a backup server each client gets
  its own SFTP user (`ops backup-client add`); on object storage each server gets
  its own prefix and a key limited to it. A compromised server can only reach
  its own backups.
- **A logical host name** (`OPS_HOST`) instead of the machine's, so history
  continues when the machine is replaced.
- **restic from the official release**, pinned with its checksum in
  `bootstrap.sh`. Distribution packages are often years old.

## Alerts

- The server emails through SMTP (with curl) when a backup, check, start or
  reload fails.
- A server that is down cannot email. An external monitor such as the Gatus
  example, on another server, checks each app's `HEALTH_URL` and expects a
  nightly heartbeat per app; a missing heartbeat raises an alert.

## Not included, on purpose

| Not included | Why |
|---|---|
| Managing several servers from one repository | One instance per server keeps them independent |
| CI deploying server configuration | It needs root-equivalent access; CI only lints |
| Label-based routing (caddy-docker-proxy, Traefik) | It needs the Docker socket inside the internet-facing container |
| Cloud resources and DNS | Done in the provider's console |
