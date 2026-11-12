# ops backup

[English](backup.md)

```text
ops backup <app>
ops backup --all
```

立即把一个应用（或所有应用）备份到它的每个目标。cron 每晚在 `BACKUP_TIME` 运行 `ops backup --all`，输出追加到 `/var/log/ops/backup.log`。

## 执行流程

1. 要求 root，加载 `ops.conf` 和 `/etc/ops/backup.env`（导出 `RESTIC_PASSWORD_FILE`）。
2. 选定应用：`--all` 时是所有带 `app.conf` 的目录，否则是指定的那个（必须存在）。
3. 创建 `/var/backups/ops`（700）和 `/var/lib/ops/backup`。
4. **加锁**：对 `/var/backups/ops/.lock` 执行 `flock -n`。另一个备份或校验正持有锁时，立即停止并提示 `another backup or check is running`。
5. 逐个应用：
   1. 加载 `app.conf`。`BACKUP_TARGETS` 为空：警告并计为失败。为 `none`：静默跳过。
   2. 清空并创建暂存目录 `/var/backups/ops/<app>` 和 `<stage>/.ops`。
   3. 以 `STAGE=<stage>` 运行 `backup-hook.sh`（在子 shell 里，`set -euo pipefail`，工作目录为 `apps/<app>`，可用 `$APP`、`$APP_DIR`、`$APP_DATA` 和 `compose` 函数）。hook 写出一份一致的副本，比如 `pg_dump` 的输出或 SQLite 在线备份。hook 失败时该应用记为 `hook` 失败，不触碰任何目标。
   4. 把 `/srv/apps/<app>/.env` 复制到 `<stage>/.ops/env`（600），恢复时可以把密钥一起带回来。
   5. 对 `BACKUP_TARGETS` 里的每个目标：
      - 没有在 `backup.env` 里定义：记为失败；
      - 否则只导出该目标的 `TARGET_<NAME>_*` 变量，执行 `restic backup --host <OPS_HOST> --tag <app> [--exclude …] <stage>`，再执行 `restic forget --tag <app> --group-by tags <BACKUP_KEEP>`（标记旧快照；数据由每周的 `ops check` 清理）。两者遇到仓库锁时最多等 10 分钟。
      - 输出 `<app> -> <target>: ok` 或 `failed`。一个目标失败不影响其他目标。
   6. 删除暂存目录。
   7. 写入 `/var/lib/ops/backup/<app>.status`（`<UTC 时间> ok` 或 `<UTC 时间> FAILED: <目标>`），`ops status` 会显示它。
   8. `alert.env` 里设置了 `HEARTBEAT_URL` 时发送心跳：填入 `{host}`、`{app}`、`{success}`（`true`/`false`），`HEARTBEAT_TOKEN` 作为 bearer token。
6. 有应用失败时：发送 `backup failed` 邮件，每个失败的应用一行，然后以 1 退出并提示 `backup finished with failures`。否则输出 `backup finished`。

每个目标都直接从暂存目录备份，从不从另一个目标复制，一个仓库损坏不会蔓延到另一个。

## 文件

| 读取 | 写入 |
|---|---|
| `apps/<app>/app.conf`、各 hook、`/srv/apps/<app>/`、`/etc/ops/backup.env`、`/etc/ops/alert.env` | restic 仓库、`/var/backups/ops/<app>/`（临时）、`/var/lib/ops/backup/<app>.status` |

## 常用形式

```bash
ops backup vaultwarden            # 有风险的改动、升级或下线应用之前
ops backup --all                  # 新服务器配置好后，或重试失败的那一晚
tail -n 50 /var/log/ops/backup.log
ops status                        # 看 LAST BACKUP 列
```

手动查看仓库内容（先加载目标的变量）：

```bash
set -a; . /etc/ops/backup.env; set +a
RESTIC_REPOSITORY=$TARGET_REMOTE_REPOSITORY restic snapshots --tag vaultwarden
```

对于 `b2`，还要导出 `AWS_ACCESS_KEY_ID=$TARGET_B2_AWS_ACCESS_KEY_ID` 和 `AWS_SECRET_ACCESS_KEY=$TARGET_B2_AWS_SECRET_ACCESS_KEY`。
