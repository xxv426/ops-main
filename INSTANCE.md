# ops-main (instance notes)

[中文](INSTANCE.zh-CN.md)

The ops instance for the main server: Oracle Cloud A1 (4 OCPU / 24 GB, ARM,
Ubuntu), Tokyo. Made from [ops-starter](https://github.com/xxv426/ops-starter);
see its README and docs for how everything works. Every command's flow and
everyday forms are in [docs/commands](docs/commands/README.md).

| App | Domains | Backups |
|---|---|---|
| [xxvlab](apps/xxvlab) | xxvlab.com, www, stats, talk | `micro`, `b2` |
| [vaultwarden](apps/vaultwarden) | vault.xxvlab.com | `micro`, `b2`, plus 7 local copies |

## This server

- SSH: `xxvlab-a1` in `~/.ssh/config` (root, key in the password manager's agent).
- Sync: `scripts/sync.sh xxvlab-a1`. Run it from Git Bash; it uses Windows
  OpenSSH so the agent's key works.
- Resource budget: 2 OCPU / 12 GB (Oracle's free allowance), not the machine size.
  Never terminate or recreate this instance.
- Firewall: TCP 22, 80, 443 and UDP 443 in the OCI security list and iptables.

## Backup targets (/etc/ops/backup.env)

| Target | Repository | Notes |
|---|---|---|
| `micro` | `sftp:backup-a1@10.0.0.221:/srv/backup/restic` | The standby server, over the VCN. Root's `/root/.ssh/id_ed25519` |
| `b2` | `s3:https://<B2 S3 endpoint>/<bucket>/restic` | Backblaze B2. Caps & Alerts at $0; hidden files kept 30 days |

The restic password is `/etc/ops/restic-password`, also in the password manager
and offline. Snapshots from before ops (tag `nightly` for xxvlab, host `ubuntu`)
were retagged `xxvlab` and are pruned by the same policy.

## Alerts (/etc/ops/alert.env)

SMTP email, plus a heartbeat per app to Gatus on the standby server
(`backup_main-xxvlab`, `backup_main-vaultwarden`).
