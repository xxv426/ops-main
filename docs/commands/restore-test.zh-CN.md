# ops restore-test

[English](restore-test.md)

```text
ops restore-test <app> [--from <target>] [--snapshot <id>] [--host <name>]
```

不触碰任何运行中服务的恢复演练：把快照恢复到临时目录，列出其中的文件，有 `verify-hook.sh` 时运行它。每个季度对每个应用做一次，不时也对每个目标做一次。

选项与 [`ops restore`](restore.zh-CN.md) 相同（`--restore-env` 会被接受并忽略）。

## 执行流程

1. 要求 root，加载 `ops.conf` 和 `/etc/ops/backup.env`。
2. 解析参数，按与 `ops restore` 完全相同的方式选定目标和快照。
3. 把快照恢复到 `/var/backups/ops/restore-<app>.XXXXXX`，命令退出时删除。
4. 按顺序列出快照里的每个文件及其大小。
5. 存在 `apps/<app>/verify-hook.sh` 时，传入 `RESTORE_DIR` 运行它；它检查恢复出的副本，不碰运行中的应用（例如对 SQLite 文件执行 `PRAGMA integrity_check`，对导出文件执行 `gunzip -t`）。失败时停止并提示 `verify-hook.sh failed`。
6. 输出 `<app>: restore test passed (<target>)`。

没有 verify hook 时，这个测试只能证明快照可读、可恢复。

## 常用形式

```bash
ops restore-test vaultwarden                 # 最新快照，第一个目标（remote）
ops restore-test vaultwarden --from b2       # 异地那份
ops restore-test umami
ops restore-test umami --from b2
```

示例的 verify hook：Vaultwarden 执行 `PRAGMA integrity_check`，输出用户数和条目数，并要求存在 `rsa_key.pem`；Umami 用 `gunzip -t` 检查导出文件，要求有结束标记，并统计表数量。
