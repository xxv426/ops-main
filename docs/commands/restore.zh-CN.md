# ops restore

[English](restore.md)

```text
ops restore <app> [--from <target>] [--snapshot <id>] [--host <name>] [--restore-env]
```

用一个快照替换应用的数据并重新启动它。不带选项时，从应用的第一个目标恢复本主机最新的快照。

| 选项 | 默认 | 用途 |
|---|---|---|
| `--from <target>` | `BACKUP_TARGETS` 里的第一个 | 从另一个目标恢复，比如第一个连不上时 |
| `--snapshot <id>` | `--host` 上该应用最新的快照 | 指定某个时间点（`restic snapshots` 可查 ID） |
| `--host <name>` | 本服务器的 `OPS_HOST` | 恢复另一台服务器的备份：迁移应用，或重建后 `OPS_HOST` 变了 |
| `--restore-env` | 关 | 用备份里的 `.env` 替换已有的 `/srv/apps/<app>/.env` |

## 执行流程

1. 要求 root，加载 `ops.conf` 和 `/etc/ops/backup.env`。
2. 解析参数；检查应用存在、目标已设置（不是 `none`）且在 `backup.env` 里有定义。
3. **找快照**：`latest` 时按 `--host <host> --tag <app>` 列出快照取最新的；一个都没有就停止。读取快照里备份的路径（当时的暂存目录）。
4. **恢复到临时目录** `/var/backups/ops/restore-<app>.XXXXXX`（`restic restore`）。命令退出时无论成败都会删除它。`RESTORE_DIR` 是其中备份的文件所在位置。
5. 创建 `/srv/apps/<app>`。
6. **密钥**：快照里有 `.ops/env` 时，如果还没有 `.env` 或带了 `--restore-env`，就安装为 `/srv/apps/<app>/.env`（600）；否则保留现有的并说明。
7. 应用有 `compose.yaml` 时：`docker compose down`（停止应用，命名卷保留），并确保网络 `app-<app>` 存在。
8. **运行 `restore-hook.sh`**，传入 `RESTORE_DIR`。hook 只启动它需要的部分（例如 `compose up -d db`），把数据放回去，启动应用交给 ops。失败时停止并提示 `restore-hook.sh failed`，应用保持停止。
9. 运行 [`ops up <app>`](up.zh-CN.md)：所有检查、拉取、启动、接入 edge、重载 Caddy。
10. **健康检查**：设置了 `HEALTH_URL` 时，每 2 秒请求一次，最多 60 秒。对带路由且 URL 为 `https://` 的应用，请求发到 `127.0.0.1` 并带上正确的主机名（有些云上的机器访问不了自己的公网 IP）。失败只是警告。
11. 输出 `<app> restored`。

当前数据怎么处理由应用的 hook 决定。Vaultwarden 示例的 hook 会把原数据保留在 `data.before-restore-*`，直到你删除它。

## 常用形式

```bash
ops restore vaultwarden                                 # 从 remote 恢复最新快照
ops restore vaultwarden --from b2                       # remote 连不上
ops restore vaultwarden --snapshot 4f9c2a1b             # 某个时间点
ops restore umami --host old --restore-env                # 在新服务器上：把应用连同 .env 一起搬过来
```

恢复前先找到要用的快照：

```bash
set -a; . /etc/ops/backup.env; set +a
RESTIC_REPOSITORY=$TARGET_REMOTE_REPOSITORY restic snapshots --tag vaultwarden
```

重建整台服务器：同步，`bootstrap.sh`，把旧的 restic 密码写入 `/etc/ops/restic-password`，从密码管理器恢复 `backup.env` 和 `alert.env`，`ops init`，然后对每个应用 `ops restore <app>`，`ops install-cron`，检查 DNS。
