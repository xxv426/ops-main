# platform/bootstrap.sh

[English](bootstrap.md)

```text
sudo /opt/ops/platform/bootstrap.sh [--web] [--deploy-key '<ssh public key>']
```

为一台全新的 Ubuntu 或 Debian 服务器准备好 ops 的运行环境，可以重复运行。第一次 `scripts/sync.sh` 之后运行一次；之后需要加上 `--web` 或发布密钥时再运行。

| 选项 | 作用 |
|---|---|
| `--web` | 这台服务器对外提供网站：在默认拒绝入站的镜像（Oracle）上，在 iptables 里放行 TCP 80、TCP 443、UDP 443 |
| `--deploy-key '<key>'` | 为 `DEPLOY_USER` 授权这把密钥，CI 用它发布静态网站 |

## 执行流程

1. 解析参数，要求 root，加载 `ops.conf`（同时检测 `OPS_ARCH`）。CPU 不是 amd64 或 arm64 时停止。
2. 读取 `/etc/os-release`；不是 Ubuntu 或 Debian 时停止。
3. `apt-get install` ca-certificates、curl、jq、rsync、sqlite3、bzip2、openssl。
4. Docker：没有安装时，在 Ubuntu 上安装 `docker.io` 和 `docker-compose-v2`；在 Debian 上停止，请你先按 docker.com 的说明安装。检查 `docker compose`（v2）可用，并启用 Docker 服务。
5. 容器日志轮转：`/etc/docker/daemon.json` 不存在时，安装 `platform/docker/daemon.json`，并在没有运行中的容器时重启 Docker（否则提示你稍后自行重启）。文件已存在但没有 `log-opts` 时，提示你手动合并。
6. restic：已安装版本不是固定版本（`0.19.1`）时，从 GitHub 下载对应架构的官方发行版，用脚本里的 SHA-256 校验后安装为 `/usr/local/bin/restic`。
7. 写入 `/etc/sysctl.d/90-bbr.conf`（fq + BBR）并生效。
8. 带 `--web` 时：如果 INPUT 链里有 REJECT 规则，安装 iptables-persistent，在它前面插入 TCP 80、TCP 443、UDP 443 的 ACCEPT 规则并保存。提醒你在云厂商防火墙里开放同样的端口。
9. 创建 `/etc/ops`、`/srv/apps`、`/var/backups/ops`（700）和 `/var/lib/ops`、`/var/log/ops`（755），并把 `/usr/local/bin/ops` 链接到 `/opt/ops/platform/bin/ops`。
10. `ops.conf` 里设置了 `DEPLOY_USER` 时：创建该用户，把 `/srv/www` 交给它；带 `--deploy-key` 时把密钥追加到它的 `authorized_keys`（不重复添加）。
11. 输出 `bootstrap finished. Next: ops init`。

## 常用形式

```bash
sudo /opt/ops/platform/bootstrap.sh --web                        # 对外提供网站的服务器
sudo /opt/ops/platform/bootstrap.sh --web --deploy-key 'ssh-ed25519 AAAA… ci'
sudo /opt/ops/platform/bootstrap.sh                              # 没有对外网站的服务器
```
