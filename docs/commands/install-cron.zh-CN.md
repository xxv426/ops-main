# ops install-cron

[English](install-cron.md)

```text
ops install-cron
```

按 `ops.conf` 安排每晚备份和每周校验，并为它们的日志配置轮转。应用都启动后运行一次；修改 `BACKUP_TIME` 或 `CHECK_TIME` 后再运行。`/etc/cron.d/ops` 存在时，`ops upgrade` 会重新运行它。

## 执行流程

1. 要求 root，加载 `ops.conf`（`BACKUP_TIME` 默认 `30 19 * * *`，`CHECK_TIME` 默认 `0 21 * * 0`）。
2. 创建 `/var/log/ops`。
3. 覆盖写入 `/etc/cron.d/ops`（644）：

   ```text
   SHELL=/bin/bash
   PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
   <BACKUP_TIME> root /opt/ops/platform/bin/ops backup --all >>/var/log/ops/backup.log 2>&1
   <CHECK_TIME>  root /opt/ops/platform/bin/ops check >>/var/log/ops/check.log 2>&1
   ```

4. 覆盖写入 `/etc/logrotate.d/ops`：`/var/log/ops/*.log` 每月轮转，保留 12 份，压缩。
5. 输出计划时间和服务器时区。cron 使用服务器时区，通常是 UTC。

## 文件

| 读取 | 写入 |
|---|---|
| `ops.conf` | `/etc/cron.d/ops`、`/etc/logrotate.d/ops` |

## 常用形式

```bash
ops install-cron
cat /etc/cron.d/ops                        # 当前安排了什么
tail -n 50 /var/log/ops/backup.log         # 昨晚的备份做了什么
tail -n 50 /var/log/ops/check.log
```

默认是每天 19:30 和每周日 21:00（服务器时间）。服务器是 UTC 时，想在北京时间 03:30 运行就设置 `BACKUP_TIME="30 19 * * *"`。
