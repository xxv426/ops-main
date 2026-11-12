# 架构

[English](architecture.md)

## starter 与实例

| | 包含什么 | 何时变化 |
|---|---|---|
| **ops-starter** | `platform/`（`ops` 命令、入口、备份、告警、bootstrap）、模板、示例、文档 | 平台改进时 |
| **实例仓库**（每台服务器一个） | starter 的全部内容，加上 `ops.conf` 和 `apps/` | 这台服务器的应用变化时 |

实例从不修改 `platform/`。它把 starter 保留为 `upstream` 远端，所以 `git merge upstream/main` 能无冲突地带来平台更新。用 clone 创建实例，不要用 GitHub 的 “Use this template”，那样会丢掉共同的历史。

## 三类状态

| 类别 | 位置 | 来源 | 是否备份 |
|---|---|---|---|
| 配置 | `/opt/ops` | 实例仓库 | 否：Git 就是备份 |
| 数据 | `/srv/apps/<app>/`、命名卷 | 应用 | 按各应用的声明 |
| 构建产物 | `/srv/www/<site>/` | CI | 否：可从 Git 重新构建 |
| 运行时 | Docker 容器和网络 | 配置和数据 | 否 |

把它们分开，其余的一切才变得简单：

- `scripts/sync.sh` 用 `rsync --delete` 整体替换 `/opt/ops`。不需要排除列表，所以永远不会删掉数据。替换之前，它会在服务器上检查 `/opt/ops` 是同一个实例（`OPS_HOST`），并且新文件能通过 `ops lint`：入口 Caddy 直接从 `/opt/ops` 读取 `apps/*/site.caddy`，坏掉的路由不能落到那里。已同步的提交记录在 `/opt/ops/.revision`。
- 备份、迁移和重建只需要考虑 `/srv/apps`。
- CI 以一个无特权用户写入 `/srv/www`，读不到任何应用的密钥。

服务器专有但不保密的设置放在 `ops.conf`（提交到 Git）。密钥放在 `/etc/ops/`（从不提交）：restic 密码、备份目标和 SMTP。

## 流量

```text
浏览器 ─► DNS ─► server:443 ─► 入口 Caddy ─► app-<app> 网络 ─► 应用
```

- 入口 Caddy 是唯一映射 80/443 的容器。它加载每个 `apps/*/site.caddy`（挂载在 `/etc/ops-apps`）以及 `/srv/www` 下的静态文件。
- 每个有 compose 文件的应用都有自己的网络 `app-<app>`，由 `ops up` 在任何 Compose 项目之外创建。只有入口加入所有网络，所以被攻破的应用访问不到其他应用。ops 在 `/var/lib/ops` 写一个 Compose 覆盖文件，让入口接入每个网络，并且不重启地把运行中的入口接入新网络。
- `ops reload-caddy` 在重载前先校验配置。普通的 `caddy reload` 失败时会把坏文件留在磁盘上，下次重启就会让所有网站下线。

## 备份

每个应用声明备份什么（它的 hook）以及备份到哪里（`BACKUP_TARGETS`）。服务器在 `/etc/ops/backup.env` 里定义目标：

```bash
TARGET_<NAME>_REPOSITORY=<任意 restic 仓库>
TARGET_<NAME>_<VAR>=<value>      # 仅在 restic 使用 <name> 时导出为 <VAR>
```

每晚，`ops backup --all` 依次处理每个应用：把它的备份 hook 输出到暂存目录，加上它的 `.env`，然后对每个目标执行 `restic backup --host <OPS_HOST> --tag <app>`，并按应用的保留策略执行 `restic forget --group-by tags`。一个应用或目标失败不会中断其他的。失败会发邮件；每个应用的结果还可以发送到心跳 URL。

每周，`ops check` 清理每个目标，并读回其中不同的 5%。

设计取舍：

- **每个目标直接备份**，而不是从另一个目标复制，一个损坏的仓库不会蔓延到另一个。
- **每台服务器在每个目标上一个仓库。** 在备份服务器上，每个客户端有自己的 SFTP 用户（`ops backup-client add`）；在对象存储上，每台服务器有自己的前缀和只限于该前缀的密钥。被攻破的服务器只能碰到自己的备份。
- **逻辑主机名**（`OPS_HOST`）而不是机器名，换机器时历史可以延续。
- **使用官方发行版的 restic**，在 `bootstrap.sh` 里固定版本并校验 checksum。发行版的软件包往往落后好几年。

## 告警

- 备份、校验、启动或重载失败时，服务器通过 SMTP（用 curl）发邮件。
- 宕机的服务器发不了邮件。放在另一台服务器上的外部监控（如 Gatus 示例）检查每个应用的 `HEALTH_URL`，并期待每个应用每晚一次心跳；缺少心跳就告警。

## 刻意不包含的内容

| 不包含 | 原因 |
|---|---|
| 用一个仓库管理多台服务器 | 每台服务器一个实例，互不影响 |
| 由 CI 部署服务器配置 | 需要 root 等价权限；CI 只做 lint |
| 基于 label 的路由（caddy-docker-proxy、Traefik） | 需要把 Docker socket 挂进面向公网的容器 |
| 云资源和 DNS | 在服务商控制台里操作 |
