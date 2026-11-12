# ops status

[English](status.md)

```text
ops status [--usage]
```

一屏看完服务器概况：平台版本和已同步的提交、每个应用运行中的容器和最近一次备份、资源预算。`--usage` 另外显示每个备份仓库的大小和每个应用的快照数。

## 执行流程

1. 加载 `ops.conf`。不调用 `require_root`，但需要能访问 Docker；`--usage` 需要读取 `/etc/ops`（所以实际上以 root 运行）。
2. 输出标题行：`OPS_HOST`、检测到的架构、`VERSION`，以及 `/opt/ops/.revision`（`sync.sh` 安装的提交，没有时显示 `unknown`）。
3. 每个应用一行：

   | 列 | 来源 |
   |---|---|
   | `APP` | 目录名 |
   | `CONTAINERS` | `运行中/已定义`，来自 `docker compose ps --status running` 和 `config --services`（profile 里的服务不计入）；没有 compose 的应用显示 `static` |
   | `LAST BACKUP` | `/var/lib/ops/backup/<app>.status`，由 `ops backup` 写入：`<UTC 时间> ok` 或 `<UTC 时间> FAILED: <目标>`；从未备份显示 `-` |
   | `TARGETS` | `app.conf` 里的 `BACKUP_TARGETS` |

4. 输出资源合计和预算的对比（只报告，从不失败）。
5. 带 `--usage` 时，对 `backup.env` 里的每个目标：输出原始数据大小（`restic stats --mode raw-data`），再列出使用该目标的每个应用的快照数。连不上的目标显示 `unavailable`。

## 常用形式

```bash
ops status                       # 日常看一眼；也可以在本地：
ssh myserver ops status
ops status --usage               # 每月：看仓库增长（较慢，要访问每个目标）
```

示例（时间和提交号仅作示意）：

```text
host: web1 (arm64)  platform: 0.1.0  revision: 65d6393 synced 2026-11-12T08:00:00Z

APP              CONTAINERS LAST BACKUP                              TARGETS
umami            2/2        2026-11-11T19:30:40Z ok                  remote b2
vaultwarden      1/1        2026-11-11T19:31:02Z ok                  remote b2

limits: 1.25 CPU, 1.8 GiB  budget: 2 CPU, 12.0 GiB
```
