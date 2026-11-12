# scripts/sync.sh

[English](sync.md)

```text
scripts/sync.sh [--force] [--no-lint] <ssh-host>
```

把实例仓库已提交的状态（`HEAD`）复制到服务器的 `/opt/ops`，并删除已从 Git 中移除的文件。在本地运行（Windows 上用 Git Bash）。它不是 `ops` 的子命令，但所有改动都经由它到达服务器。

## 执行流程

本地：

1. 解析参数；缺少主机或参数无法识别时输出用法并以 1 退出。
2. `cd` 到 Git 仓库根目录。
3. 选择 SSH 客户端：设置了 `$OPS_SSH` 就用它；否则如果存在 Windows OpenSSH（`/c/Windows/System32/OpenSSH/ssh.exe`）就用它；再否则用 `ssh`。Windows OpenSSH 能使用密码管理器 agent 里的密钥，Git Bash 自带的 `ssh` 不能。
4. 工作区有未提交的改动时给出警告：只发送 `HEAD`。
5. 仓库里没有 `ops.conf` 时给出警告。
6. 把 `git archive --format=tar HEAD` 通过 SSH 流式传给远端脚本。

服务器上（以 root 运行；SSH 用户不是 root 时用 `sudo -n`）：

7. 把归档解压到临时目录，写入 `.revision`（`<短提交号> synced <UTC 时间>`）。
8. **主机检查。** 分别从新的 `ops.conf` 和现有的 `/opt/ops/ops.conf` 读取 `OPS_HOST`。两者都存在且不同时，不做任何改动直接停止，除非加了 `--force`。这样一台服务器的实例不会被另一台的覆盖。
9. **lint 检查。** 除非加了 `--no-lint`，且新目录里有 `OPS_HOST`，就针对临时目录运行 `ops lint`（`OPS_ROOT=<临时目录>`）。失败则不做任何改动直接停止，坏掉的路由永远不会进入 edge Caddy 读取的目录。如果还没装 Docker 或 jq（`bootstrap.sh` 之前），给出提示并跳过 lint。
10. 用 `rsync -a --delete --chown=root:root` 替换 `/opt/ops`；没有 rsync 时，把旧目录移开、新目录移入。
11. 删除临时目录。

回到本地输出 `synced <commit> to <host>:/opt/ops`。

同步只更新文件，不重启任何东西：之后要运行 `ops up <app>`、`ops reload-caddy` 或 `ops upgrade`。（Caddy 直接从 `/opt/ops` 读取 `apps/*/site.caddy`，但只有收到指令才会重新加载。）

## 文件

| 读取 | 写入 |
|---|---|
| 本地仓库的 `HEAD` | `/opt/ops/**`（整体替换）、`/opt/ops/.revision` |

`/srv/apps`、`/srv/www`、`/etc/ops` 从不触碰。

## 失败

| 信息 | 含义 |
|---|---|
| `/opt/ops on this server is the instance OPS_HOST=…` | SSH 主机写错，或服务器被挪作他用。检查主机；`--force` 强制替换 |
| `ops lint failed on the new files` | 修复 lint 问题后重新提交；`--no-lint` 跳过检查 |
| `sudo: a password is required` | SSH 用户需要是 root 或有免密 sudo |

## 常用形式

```bash
scripts/sync.sh myserver                    # 最常用
git commit -am "..." && scripts/sync.sh myserver
scripts/sync.sh --no-lint myserver          # 暂时无法 lint，例如镜像拉不下来
OPS_SSH=ssh scripts/sync.sh myserver        # 指定 ssh 客户端
```
