# ops backup-client

[English](backup-client.md)

```text
ops backup-client add <name> '<ssh public key>'
```

在通过 SFTP 存放**其他**服务器备份的机器上运行（比如一台小的备用服务器）。每个客户端一个受限用户和目录，被入侵的客户端只能碰到自己的仓库。

## 执行流程

1. 要求 root。不读取 `ops.conf`。
2. 检查参数：动作必须是 `add`，名字只能是小写字母、数字和连字符，密钥必须以 `ssh-` 开头。
3. 用户 `backup-<name>` 不存在时创建（带主目录和 bash）。
4. 创建 `~backup-<name>/.ssh`（700），并用 `restrict <key>` **替换**它的 `authorized_keys`（600）。`restrict` 关闭端口转发、agent 转发、X11 和 PTY 分配，SFTP 仍然可用。用新密钥再运行一次会替换掉旧密钥。
5. 创建 `/srv/backup`（755）和 `/srv/backup/<name>`（700，属于该用户）。
6. 输出客户端要用的仓库地址：`sftp:backup-<name>@<this server>:/srv/backup/<name>`。

## 然后在客户端上

```bash
# 客户端的 /etc/ops/backup.env
TARGET_REMOTE_REPOSITORY=sftp:backup-<name>@<backup server>:/srv/backup/<name>
```

使用 root 的密钥（`/root/.ssh/id_ed25519`），把备份服务器加进 root 的 `known_hosts`，然后 `ops init --init-missing`。

## 常用形式

在备份服务器上：

```bash
ops backup-client add b "$(ssh server-b cat /root/.ssh/id_ed25519.pub)"
```
