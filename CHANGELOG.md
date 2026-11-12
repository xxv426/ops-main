# Changelog

Upgrade an instance with `git fetch upstream && git merge upstream/main`, then
sync and run `ops upgrade` on the server. Steps beyond that are listed under
each version.

## Unreleased

- Alerts: send SMTP credentials with `--sasl-ir`; QQ Mail rejected curl's
  default two-step AUTH PLAIN.

## 0.1.0

First version: `ops` command, edge Caddy with one network per app, restic
backups with per-app targets, SMTP alerts and heartbeats, bootstrap for Ubuntu
and Debian, examples for a static site, Vaultwarden, Umami and Gatus.
