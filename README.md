# ops-starter

A small, generic toolkit for running a few self-hosted apps on one server with
Docker Compose: one Caddy in front of everything, one network per app, restic
backups that each app declares for itself, and email alerts.

This repository holds no server or app of its own. Each server gets its own
**instance repository** made from it, which adds only `ops.conf`, the server's
apps under `apps/`, and an `INSTANCE.md` with notes about that server. Platform
improvements are made here and merged into every instance; an instance never
edits the starter's files, so those merges do not conflict.

```text
ops-starter ──► ops-main     (server A: apps 1, 2, 3)
            ──► ops-standby  (server B: apps 4, 5, 6)
```

## What a server gets

| Piece | What it does |
|---|---|
| `ops` command | Starts and stops apps, reloads Caddy safely, backs up, restores, alerts |
| Edge Caddy | The only container on ports 80/443; HTTPS for every app's domains |
| One network per app | Apps cannot reach each other, only the edge can reach them |
| Backups | restic to the targets each app lists in `app.conf`; nightly backup, weekly prune and check |
| Alerts | Email through SMTP on any failure; optional heartbeats to an external monitor |
| Guard rails | Resource budget, pinned images, no public ports except through Caddy |

Where things live on a server:

| Path | Contents | Source |
|---|---|---|
| `/opt/ops` | This repository's files (via the instance repository) | Git, replaced on every sync |
| `/srv/apps/<app>/` | The app's data and `.env` | The app; backed up as declared |
| `/srv/www/<site>/` | Static sites | CI; rebuilt from Git |
| `/etc/ops/` | restic password, backup targets, SMTP | You, on the server; never in Git |

## Start a new server

On your machine:

```bash
git clone <ops-starter url> ops-<server>
cd ops-<server>
git remote rename origin upstream        # keep the starter's history for later merges
git remote add origin <new private repository url>
cp ops.conf.example ops.conf             # fill it in; notes about the server go in INSTANCE.md
cp -r examples/vaultwarden apps/vaultwarden   # or: platform/bin/ops new <app>
# edit the app's files, then:
git add -A && git commit -m "Initialize ops-<server>" && git push -u origin main
scripts/sync.sh <ssh-host>
```

On the server, as root:

```bash
/opt/ops/platform/bootstrap.sh --web     # --web if it serves sites; see --deploy-key for CI
ops init --generate-password             # or put an existing password in /etc/ops/restic-password
# fill in /etc/ops/backup.env and /etc/ops/alert.env when ops init asks, then:
ops init --init-missing                  # checks or creates every backup repository, sends a test email
ops up <app>                             # for each app
ops install-cron
ops backup --all                         # once by hand
```

Save the restic password in your password manager **and** offline. Without it no
backup can be read.

## Day to day

| Task | Steps |
|---|---|
| Change an app | Edit, commit, `scripts/sync.sh <host>`, then `ops up <app>` (or `ops reload-caddy` for routes only) |
| Add an app | `platform/bin/ops new <app>` or copy an example; add DNS and wait for it to resolve; commit, sync, `ops up <app>` |
| Remove an app | `ops backup <app>`, `ops down <app>`, delete the directory, commit, sync, `ops reload-caddy` |
| Restore | `ops restore <app>` (newest snapshot of the first target), `--from <target>`, `--snapshot <id>` |
| Drill | `ops restore-test <app>` each quarter |
| Move an app to another server | `ops backup` and `ops down` on the old one; move the directory between instance repositories; `ops restore <app> --host <old host>` and `ops up` on the new one; switch DNS |
| Upgrade the platform | In the instance: `git fetch upstream && git merge upstream/main`, read `CHANGELOG.md`, push, sync, `ops upgrade` |

Run `ops` without arguments for every command.

## Docs

- [docs/architecture.md](docs/architecture.md): how it fits together and why
- [docs/apps.md](docs/apps.md): writing an app directory
- [examples/](examples): static site, Vaultwarden (SQLite), Umami (Postgres), Gatus (monitoring)
