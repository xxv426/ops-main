# ops check

[English](check.md)

```text
ops check
```

维护每个备份目标：删除已没有快照引用的数据，然后校验仓库并随机读回 5% 的数据。cron 每周在 `CHECK_TIME` 运行它，输出追加到 `/var/log/ops/check.log`。

## 执行流程

1. 要求 root，加载 `ops.conf` 和 `/etc/ops/backup.env`。
2. 创建 `/var/backups/ops`。
3. **加锁**：对 `/var/backups/ops/.lock` 执行 `flock`，**等待**正在运行的备份结束（不同于 `ops backup` 立即放弃）。
4. 对 `backup.env` 里定义的每个目标（不论是否有应用在用）：
   1. `restic prune`：删除每晚备份时 `restic forget` 释放的数据。
   2. `restic check --read-data-subset=5%`：检查仓库结构，并随机读回 5% 的数据包，日积月累大部分数据都会被读到。
   3. 输出 `<target>: ok` 或 `failed`；失败不影响下一个目标。
   两者遇到仓库锁时最多等 10 分钟。
5. 有目标失败时：发送 `backup check failed` 邮件并列出目标，以 1 退出。否则输出 `check finished`。

## 常用形式

```bash
ops check                             # 某个目标恢复连通后，或收到失败邮件后手动执行
tail -n 50 /var/log/ops/check.log
```

仓库很大时会运行很久。手动执行时放在 `tmux` 里或用 `nohup`。
