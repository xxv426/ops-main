# platform/bootstrap.sh

[中文](bootstrap.zh-CN.md)

```text
sudo /opt/ops/platform/bootstrap.sh [--web] [--deploy-key '<ssh public key>']
```

Prepares a fresh Ubuntu or Debian server for ops. Safe to run again. Run it once
after the first `scripts/sync.sh`, and again when you add `--web` or a deploy
key.

| Option | Effect |
|---|---|
| `--web` | The server serves sites: open TCP 80, TCP 443 and UDP 443 in iptables where the image rejects by default (Oracle) |
| `--deploy-key '<key>'` | Authorize this key for `DEPLOY_USER`, which CI uses to publish static sites |

## Flow

1. Parses the options, requires root, loads `ops.conf` (which detects
   `OPS_ARCH`). Stops on CPUs other than amd64 and arm64.
2. Reads `/etc/os-release`; stops unless the system is Ubuntu or Debian.
3. `apt-get install` ca-certificates, curl, jq, rsync, sqlite3, bzip2, openssl.
4. Docker: if missing, installs `docker.io` and `docker-compose-v2` on Ubuntu;
   on Debian stops and asks you to install Docker from docker.com first. Checks
   that `docker compose` (v2) works and enables the Docker service.
5. Container log rotation: if `/etc/docker/daemon.json` does not exist, installs
   `platform/docker/daemon.json` and restarts Docker when no container is
   running (otherwise warns you to restart it later). If the file exists without
   `log-opts`, warns you to merge it by hand.
6. restic: unless the installed version is the pinned one (`0.19.1`), downloads
   the official release for the architecture from GitHub, checks its SHA-256
   against the checksum in the script, and installs it as
   `/usr/local/bin/restic`.
7. Writes `/etc/sysctl.d/90-bbr.conf` (fq + BBR) and applies it.
8. With `--web`: if the INPUT chain contains a REJECT rule, installs
   iptables-persistent and inserts ACCEPT rules for TCP 80, TCP 443 and UDP 443
   before it, then saves. Reminds you to open the same ports in the cloud
   firewall.
9. Creates `/etc/ops`, `/srv/apps`, `/var/backups/ops` (700) and
   `/var/lib/ops`, `/var/log/ops` (755), and links `/usr/local/bin/ops` to
   `/opt/ops/platform/bin/ops`.
10. If `DEPLOY_USER` is set in `ops.conf`: creates the user, gives it
    `/srv/www`, and with `--deploy-key` appends the key to its
    `authorized_keys` (once).
11. Prints `bootstrap finished. Next: ops init`.

## Common usage

```bash
sudo /opt/ops/platform/bootstrap.sh --web                        # a server that serves sites
sudo /opt/ops/platform/bootstrap.sh --web --deploy-key 'ssh-ed25519 AAAA… ci'
sudo /opt/ops/platform/bootstrap.sh                              # a server without public sites
```
