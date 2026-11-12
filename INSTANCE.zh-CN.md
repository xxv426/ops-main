# ops-main（实例说明）

[English](INSTANCE.md)

主服务器的 ops 实例：Oracle Cloud A1（4 OCPU / 24 GB，ARM，Ubuntu），东京。由 [ops-starter](https://github.com/xxv426/ops-starter) 生成；一切如何运作见它的 README 和文档。每个命令的执行流程和常用形式见 [docs/commands/README.zh-CN.md](docs/commands/README.zh-CN.md)。

| 应用 | 域名 | 备份 |
|---|---|---|
| [xxvlab](apps/xxvlab) | xxvlab.com、www、stats、talk | `micro`、`b2` |
| [vaultwarden](apps/vaultwarden) | vault.xxvlab.com | `micro`、`b2`，另加 7 份本地副本 |

## 这台服务器

- SSH：`~/.ssh/config` 里的 `xxvlab-a1`（root，密钥在密码管理器的 agent 里）。
- 同步：`scripts/sync.sh xxvlab-a1`。在 Git Bash 里运行；它使用 Windows OpenSSH，这样 agent 里的密钥才能用。
- 资源预算：2 OCPU / 12 GB（Oracle 的免费额度），不是机器规格。永远不要终止或重建这台实例。
- 防火墙：OCI 安全列表和 iptables 里开放 TCP 22、80、443 和 UDP 443。

## 备份目标（/etc/ops/backup.env）

| 目标 | 仓库 | 说明 |
|---|---|---|
| `micro` | `sftp:backup-a1@10.0.0.221:/srv/backup/restic` | 备用服务器，走 VCN 内网。使用 root 的 `/root/.ssh/id_ed25519` |
| `b2` | `s3:https://<B2 S3 endpoint>/<bucket>/restic` | Backblaze B2。Caps & Alerts 上限 $0；隐藏的文件保留 30 天 |

restic 密码是 `/etc/ops/restic-password`，密码管理器里和离线各有一份。ops 之前的快照（xxvlab 的标签 `nightly`，主机 `ubuntu`）已改打 `xxvlab` 标签，按同样的策略清理。

## 告警（/etc/ops/alert.env）

SMTP 邮件，外加每个应用向备用服务器上的 Gatus 发送心跳（`backup_main-xxvlab`、`backup_main-vaultwarden`）。
