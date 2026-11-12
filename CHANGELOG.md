# Changelog

[中文](CHANGELOG.zh-CN.md)

Upgrade an instance with `git fetch upstream && git merge upstream/main`, then
sync and run `ops upgrade` on the server. Steps beyond that are listed under
each version.

## Unreleased

- Docs: one page per command in `docs/commands/` with its step-by-step flow and
  everyday forms, and a Chinese version (`*.zh-CN.md`) of every document.
- `ops.conf`: `OPS_ARCH` is gone; the architecture is detected on the server.
  Remove the line from your `ops.conf` (`ops lint` reminds you). Only `OPS_HOST`
  and the resource budget are required.
- `scripts/sync.sh` checks on the server, before changing anything, that
  `/opt/ops` belongs to the same `OPS_HOST` and that `ops lint` passes on the new
  files. `--force` and `--no-lint` skip the checks. It records the synced commit
  in `/opt/ops/.revision`, shown by `ops status`.
- Alerts: send SMTP credentials with `--sasl-ir`; QQ Mail rejected curl's
  default two-step AUTH PLAIN.

## 0.1.0

First version: `ops` command, edge Caddy with one network per app, restic
backups with per-app targets, SMTP alerts and heartbeats, bootstrap for Ubuntu
and Debian, examples for a static site, Vaultwarden, Umami and Gatus.
