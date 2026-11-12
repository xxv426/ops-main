# 编写应用

[English](apps.md)

应用是实例仓库 `apps/` 下的一个目录。ops 只读取这里列出的内容。

```text
apps/<app>/
├── app.conf          必需：ops 需要知道的信息
├── README.md         必需：它是什么，以及有什么特别之处
├── compose.yaml      容器（纯静态网站没有）
├── site.caddy        对外路由（不对外的应用没有）
├── .env.example      需要哪些密钥，不含值
├── backup-hook.sh    开启备份时必需：把一致的数据写到 $STAGE
├── restore-hook.sh   开启备份时必需：把 $RESTORE_DIR 放回去
└── verify-hook.sh    可选：为 `ops restore-test` 检查恢复出的副本
```

`platform/bin/ops new <app>` 从 `platform/templates/app` 创建一个。`examples/` 目录里有可以直接复制的完整应用。

## app.conf

```bash
APP_DOMAINS="vault.example.com"
HEALTH_URL="https://vault.example.com/alive"   # 恢复后检查，监控也用它
BACKUP_TARGETS="remote b2"                      # 必需：/etc/ops/backup.env 里的名字，或 none
BACKUP_KEEP="--keep-daily 14 --keep-weekly 8 --keep-monthly 12"
BACKUP_EXCLUDE=""                               # restic --exclude 模式，空格分隔
```

`BACKUP_TARGETS` 没有默认值。`ops up` 拒绝启动没有设置它的应用，也拒绝服务器没有定义的目标。

建议的级别：

| 数据 | `BACKUP_TARGETS` | 保留 |
|---|---|---|
| 丢了就永远找不回 | 所有目标，至少一个异地 | 14 天、8 周、12 个月 |
| 重建很痛苦 | 近处的目标 | 7 天、4 周、6 个月 |
| 可以重新下载或从 Git 重建 | `none` | — |

## compose.yaml

- `name:` 就是应用名。
- 数据放在 `/srv/apps/<app>/` 下（绑定挂载）或命名卷里。
- 密钥来自 `/srv/apps/<app>/.env`。ops 把它传给 Compose，既用于 `${VAR}` 插值，也用于 `env_file`。在 `env_file` 上设置 `required: false`，这样没有它时 `ops lint` 也能运行；`.env.example` 里每个键都有值之前，`ops up` 拒绝启动。
- 公网流量只走入口：加入外部网络 `app-<app>`，不映射公网端口。管理端口绑定到 `127.0.0.1`。
- 数据库放进 `internal: true` 网络。
- 每个服务都设置 `cpus` 和 `mem_limit`；合计必须在 `ops.conf` 的预算之内。
- 每个镜像都固定版本，且必须有服务器 CPU 架构的版本；`ops up` 会检查。

## site.caddy

只写这个应用的站点块。上游写 Compose 服务名。可以使用 `platform/edge/caddy/Caddyfile` 里的片段：

- `import security_headers`：HSTS、nosniff、referrer policy，去掉 `Server` 头。
- `import static_site <site> <hashed prefix>`：提供 `/srv/www/<site>/current`，支持预压缩文件，带哈希的资源长期缓存。

第一次 `ops up` 之前先添加 DNS 记录并等待解析生效，否则 Let's Encrypt 验证会反复失败，导致该域名被限流。

## Hook

hook 由 ops 在一个带 `set -euo pipefail` 的子 shell 里 source。它们可以使用：

| 名称 | 值 |
|---|---|
| `$APP` | 应用名 |
| `$APP_DIR` | 应用在 `/opt/ops/apps` 里的目录（也是工作目录） |
| `$APP_DATA` | `/srv/apps/<app>` |
| `$STAGE` | 备份 hook：要写入的空目录 |
| `$RESTORE_DIR` | 恢复和校验 hook：备份 hook 当时写出的文件 |
| `compose ...` | 这个应用的 `docker compose` |

ops 自己会把 `/srv/apps/<app>/.env` 加进每次备份，并在它缺失时（或带 `--restore-env` 时）恢复它，所以 hook 从不处理它。

- **backup-hook.sh**：写出一份一致的副本。使用数据库自己的工具（`pg_dump`、`sqlite3 .backup`），绝不复制正在使用的数据库文件。有任何疑问就以非零退出。
- **restore-hook.sh**：在应用停止时运行。只启动它需要的部分（`compose up -d db`），把数据放回去，启动应用交给 ops。
- **verify-hook.sh**：检查恢复出的副本，不碰运行中的应用，例如 `PRAGMA integrity_check` 或 `gunzip -t`。

各个命令的详细执行流程见 [commands/README.zh-CN.md](commands/README.zh-CN.md)。
