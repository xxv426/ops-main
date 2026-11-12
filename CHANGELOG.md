# Changelog

Upgrade an instance with `git fetch upstream && git merge upstream/main`, then
sync and run `ops upgrade` on the server. Steps beyond that are listed under
each version.

## 0.1.0

First version: `ops` command, edge Caddy with one network per app, restic
backups with per-app targets, SMTP alerts and heartbeats, bootstrap for Ubuntu
and Debian, examples for a static site, Vaultwarden, Umami and Gatus.
