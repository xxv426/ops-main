# ops init

[English](init.md)

```text
ops init [--generate-password] [--init-missing]
```

创建并检查 `/etc/ops` 下的一切：restic 密码、备份目标、告警设置。幂等：每次运行创建缺少的部分，**遇到第一个需要你填写的文件就停下**；全部就绪后检查每个备份目标并发一封测试邮件。反复运行，直到输出 `init finished`。

| 选项 | 作用 |
|---|---|
| `--generate-password` | 没有 restic 密码时随机生成一个 |
| `--init-missing` | 对还不存在的目标仓库执行 `restic init` 创建 |

## 执行流程

1. 要求 root，加载 `ops.conf`，解析参数（无法识别的参数会让它停止）。
2. 创建 `/etc/ops`（700）、`/var/lib/ops` 和 `/var/log/ops`（755）、`/var/backups/ops` 和 `/srv/apps`（700）。
3. **完全不需要备份？** 如果每个应用都是 `BACKUP_TARGETS=none`，跳过 restic：`alert.env` 不存在时从模板创建并停下让你填写，然后发测试告警并结束。
4. **restic 密码。** `/etc/ops/restic-password` 不存在或为空时：
   - 带 `--generate-password`：写入 32 个随机字节的十六进制（`openssl rand -hex 32`，umask 077），并提醒你立即保存一份；
   - 否则停止，请你把已有的密码写进去。

   然后把文件权限设为 600。
5. **backup.env。** `/etc/ops/backup.env` 不存在时，安装 `platform/templates/backup.env.example`（600）并停下让你填写。
6. 加载 `backup.env`（要求设置了 `RESTIC_PASSWORD_FILE` 且可读），列出所有目标（`TARGET_<NAME>_REPOSITORY`）。一个都没有时给出警告。
7. **逐个目标：** 用该目标的变量执行 `restic cat config`。
   - 可访问：输出 `repository is reachable`。
   - 不可访问且带 `--init-missing`：执行 `restic init`，输出 `repository created`。
   - 其他情况：停止。要么 `backup.env` 写错了，要么仓库还不存在。
8. **alert.env。** `/etc/ops/alert.env` 不存在时，安装模板并停下让你填写。权限设为 600。
9. 发测试告警（`ops alert-test`）。失败时停止，提示 `fix alert.env, then run ops init again`。
10. 输出 `init finished. Next: ops up <app> for each app, then ops install-cron`。

## 文件

| 读取 | 写入 |
|---|---|
| `ops.conf`、`apps/*/app.conf`、各目标的仓库 | `/etc/ops/restic-password`、`/etc/ops/backup.env`、`/etc/ops/alert.env`（来自模板）、新建的 restic 仓库 |

## 常用形式

新服务器，一步一步来：

```bash
ops init --generate-password    # 生成密码，然后创建 backup.env；停下
vi /etc/ops/backup.env          # 定义 TARGET_REMOTE_* 和 TARGET_B2_*
ops init --init-missing         # 检查/创建仓库，创建 alert.env；停下
vi /etc/ops/alert.env           # SMTP 设置、心跳地址
ops init                        # 全部检查一遍，发测试邮件
```

沿用已有密码（迁移或重建服务器）：

```bash
install -m 600 /dev/stdin /etc/ops/restic-password   # 粘贴密码后按 Ctrl-D
ops init
```

以后在 `backup.env` 里新增目标后：

```bash
ops init --init-missing
```
