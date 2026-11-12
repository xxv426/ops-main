# scripts/sync.sh

[中文](sync.zh-CN.md)

```text
scripts/sync.sh [--force] [--no-lint] <ssh-host>
```

Copies the committed state of the instance repository (`HEAD`) to `/opt/ops` on
a server and deletes files that were removed from Git. Runs on your machine
(Git Bash on Windows). It is not an `ops` subcommand, but every change reaches a
server through it.

## Flow

On your machine:

1. Parses the options; a missing host or unknown option prints the usage and
   exits 1.
2. `cd`s to the top of the Git repository.
3. Picks the SSH client: `$OPS_SSH` if set, otherwise Windows OpenSSH
   (`/c/Windows/System32/OpenSSH/ssh.exe`) if present, otherwise `ssh`. Windows
   OpenSSH can use keys held by the password manager's agent; Git Bash's `ssh`
   cannot.
4. Warns if the working tree has uncommitted changes: only `HEAD` is sent.
5. Warns if the repository has no `ops.conf`.
6. Streams `git archive --format=tar HEAD` over SSH into a remote script.

On the server (as root, or with `sudo -n` if the SSH user is not root):

7. Unpacks the archive into a temporary directory and writes
   `.revision` (`<short commit> synced <UTC time>`).
8. **Host guard.** Reads `OPS_HOST` from the new `ops.conf` and from the
   existing `/opt/ops/ops.conf`. If both exist and differ, stops without
   changing anything, unless `--force`. This keeps one server's instance from
   being synced over another's.
9. **Lint guard.** Unless `--no-lint`, and if the new tree has an `OPS_HOST`,
   runs `ops lint` against the temporary directory (`OPS_ROOT=<tmp>`). A failure
   stops without changing anything, so a broken route never reaches the
   directory the edge Caddy reads. If Docker or jq is not installed yet (before
   `bootstrap.sh`), prints a note and skips the lint.
10. Replaces `/opt/ops` with `rsync -a --delete --chown=root:root`, or, without
    rsync, by moving the old directory aside and the new one in.
11. Removes the temporary directory.

Back on your machine it prints `synced <commit> to <host>:/opt/ops`.

Syncing changes files only. Nothing restarts: run `ops up <app>`,
`ops reload-caddy` or `ops upgrade` afterwards. (Caddy reads `apps/*/site.caddy`
from `/opt/ops` directly, but only reloads it when told to.)

## Files

| Reads | Writes |
|---|---|
| `HEAD` of the local repository | `/opt/ops/**` (replaced wholesale), `/opt/ops/.revision` |

`/srv/apps`, `/srv/www` and `/etc/ops` are never touched.

## Failures

| Message | Meaning |
|---|---|
| `/opt/ops on this server is the instance OPS_HOST=…` | Wrong SSH host, or a server being reused. Check the host; `--force` replaces it |
| `ops lint failed on the new files` | Fix the lint problem and commit again; `--no-lint` skips the check |
| `sudo: a password is required` | The SSH user needs root or passwordless sudo |

## Common usage

```bash
scripts/sync.sh myserver                    # the usual form
git commit -am "..." && scripts/sync.sh myserver
scripts/sync.sh --no-lint myserver          # lint cannot run yet, e.g. image not pullable
OPS_SSH=ssh scripts/sync.sh myserver        # force a particular ssh client
```
