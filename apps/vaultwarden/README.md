# Vaultwarden

[中文](README.zh-CN.md)

A Bitwarden-compatible password manager backed by SQLite.

- The admin panel is not public: `ssh -L 8081:127.0.0.1:8081 <server>`, then
  open `http://127.0.0.1:8081/admin`.
- Backups: a SQLite online backup plus attachments, sends, `config.json` and
  `rsa_key*`, checked with `PRAGMA integrity_check`. `LOCAL_COPIES` extra plain
  copies stay in `/var/backups/vaultwarden` for the fastest restore.
- `ops restore-test vaultwarden` checks the newest snapshot and counts users and
  items.
- A restore keeps the previous data in `data.before-restore-*` until you delete it.
- Keep the restic password somewhere besides this vault. If the server and the
  vault are lost together, a password stored only here cannot be reached.
