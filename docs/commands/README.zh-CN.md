# ops 命令参考

[English](README.md)

每个命令一页：它按什么步骤执行（依据 `platform/` 里的代码）、读写哪些文件、会怎样失败，以及日常最常用的写法。示例使用 SSH 主机 `myserver` 和示例应用 `vaultwarden`、`umami`（`examples/`），备份目标是 `platform/templates/backup.env.example` 里的 `remote` 和 `b2`。

## 各命令在哪里运行

| 命令 | 运行位置 | 需要 root | 页面 |
|---|---|---|---|
| `scripts/sync.sh <host>` | 本地 | 否 | [sync](sync.zh-CN.md) |
| `bootstrap.sh` | 服务器，一次 | 是 | [bootstrap](bootstrap.zh-CN.md) |
| `ops init` | 服务器，一次 | 是 | [init](init.zh-CN.md) |
| `ops install-cron` | 服务器 | 是 | [install-cron](install-cron.zh-CN.md) |
| `ops backup-client add` | 备份服务器 | 是 | [backup-client](backup-client.zh-CN.md) |
| `ops up <app>\|edge` | 服务器 | 是 | [up](up.zh-CN.md) |
| `ops down <app>` | 服务器 | 是 | [down](down.zh-CN.md) |
| `ops logs <app>\|edge` | 服务器 | 需能访问 Docker | [logs](logs.zh-CN.md) |
| `ops reload-caddy` | 服务器 | 是 | [reload-caddy](reload-caddy.zh-CN.md) |
| `ops status [--usage]` | 服务器 | 需能访问 Docker；`--usage` 需要 root | [status](status.zh-CN.md) |
| `ops rollback <site> [release]` | 服务器 | 是 | [rollback](rollback.zh-CN.md) |
| `platform/bin/ops new <app>` | 本地 | 否 | [new](new.zh-CN.md) |
| `ops backup <app>\|--all` | 服务器（cron 也会跑） | 是 | [backup](backup.zh-CN.md) |
| `ops check` | 服务器（cron 也会跑） | 是 | [check](check.zh-CN.md) |
| `ops restore <app>` | 服务器 | 是 | [restore](restore.zh-CN.md) |
| `ops restore-test <app>` | 服务器 | 是 | [restore-test](restore-test.zh-CN.md) |
| `ops alert-test` | 服务器 | 是 | [alert-test](alert-test.zh-CN.md) |
| `platform/bin/ops lint` | 本地、CI、服务器（由 sync 调用） | 否 | [lint](lint.zh-CN.md) |
| `ops upgrade` | 服务器 | 是 | [upgrade](upgrade.zh-CN.md) |
| `ops version` | 任意 | 否 | 见下文 |
| `ops` / `ops help` | 任意 | 否 | 见下文 |

`ops version` 输出 `VERSION` 文件（平台版本号，如 `0.1.0`）。`ops`、`ops help`、`-h`、`--help` 输出用法；未知命令把用法输出到 stderr 并以 1 退出。

## 命令是怎么启动的

每次调用 `ops` 都经过 `platform/bin/ops`：

1. 顺着 `/usr/local/bin/ops` 软链接找到自身路径，把 `OPS_ROOT` 设为仓库根目录（通常是 `/opt/ops`），已设置则沿用。
2. 加载 `platform/lib/{common,edge,apps,backup,alert,init,lint}.sh`。
3. 按第一个参数分派到对应的 `cmd_*` 函数。

大多数命令接着调用 `require_root` 和 `load_ops_conf`：加载 `ops.conf`，要求有 `OPS_HOST`、`RESOURCE_BUDGET_CPUS`、`RESOURCE_BUDGET_MEM`，根据 `uname -m` 检测 `OPS_ARCH`（`amd64` 或 `arm64`），并为 `BACKUP_TIME`、`CHECK_TIME`、`DEPLOY_USER` 填默认值。

路径可以用环境变量覆盖。CI 里的 `lint`、以及 `sync.sh` 在安装前检查新文件，都是这样做的：

| 变量 | 默认值 |
|---|---|
| `OPS_ROOT` | 包含 `platform/bin/ops` 的仓库 |
| `OPS_CONF` | `$OPS_ROOT/ops.conf` |
| `OPS_APPS_DIR` | `$OPS_ROOT/apps` |
| `OPS_ETC` | `/etc/ops` |
| `OPS_STATE` | `/var/lib/ops` |
| `OPS_LOG_DIR` | `/var/log/ops` |
| `OPS_STAGE_ROOT` | `/var/backups/ops` |
| `OPS_DATA_ROOT` | `/srv/apps` |
| `OPS_WWW_ROOT` | `/srv/www` |

## 日常操作组合

修改应用的 compose 文件或 `.env`：

```bash
git commit -am "..." && scripts/sync.sh myserver     # 本地
ssh myserver ops up vaultwarden                     # 服务器
```

只改路由（`site.caddy`）：

```bash
git commit -am "..." && scripts/sync.sh myserver
ssh myserver ops reload-caddy
```

查看服务器状况：

```bash
ssh myserver ops status
ssh myserver ops logs vaultwarden -f
ssh myserver tail -n 50 /var/log/ops/backup.log
```

升级平台：

```bash
git fetch upstream && git merge upstream/main         # 读 CHANGELOG.md
git push && scripts/sync.sh myserver
ssh myserver ops upgrade
```

每季度演练：

```bash
ssh myserver ops restore-test vaultwarden
ssh myserver ops restore-test umami --from b2
```
