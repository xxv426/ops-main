# ops lint

[English](lint.md)

```text
platform/bin/ops lint
```

对实例仓库做静态检查。需要 Docker 和 jq，不需要 root，所以可以在本地运行、在 CI 里运行（`.github/workflows/lint.yml`，每次推送都会跑），也会在服务器上由 `scripts/sync.sh` 在安装新文件之前运行。

## 执行流程

1. 加载 `ops.conf`，列出应用。
2. `ops.conf` 里还有 `OPS_ARCH=` 一行时给出警告（现在自动检测）。
3. 逐个应用检查（每个问题计数一次，检查继续进行）：
   - 名字只用小写字母、数字和连字符；
   - 存在 `README.md`；
   - 设置了 `BACKUP_TARGETS`；不是 `none` 时，设置了 `BACKUP_KEEP`，且存在 `backup-hook.sh` 和 `restore-hook.sh`；
   - 有 `compose.yaml` 时，`docker compose config` 能通过，并且：
     - 项目 `name:` 等于应用名；
     - 带 `site.caddy` 的应用加入了外部网络 `app-<app>`；
     - 没有在所有网卡上映射端口（绑定到 `127.0.0.1` 或内网 IP）；
     - 每个镜像都有版本标签，且不是 `latest`。
4. **资源预算**：每个服务都有 `cpus` 和 `mem_limit`，合计（含 edge）不超过 `ops.conf` 里的预算。有服务缺少限制时，这一项会让 lint 立即停止。
5. **Caddy**：有应用带路由时，用 edge 的 Caddy 镜像起一个临时容器，只读挂载 `platform/edge/caddy` 和 `apps/`，校验整个配置。
6. **shellcheck**（已安装时）：以 warning 级别检查 `platform/`、`scripts/`、`apps/` 下所有 `*.sh` 以及 `platform/bin/ops`。
7. 以 1 退出并提示 `<n> problem(s) found`，或输出 `lint passed`。

## 常用形式

```bash
platform/bin/ops lint                                         # 提交之前
OPS_CONF=ops.conf.example OPS_APPS_DIR=examples platform/bin/ops lint   # 检查示例，和 starter 的 CI 一样
```

Windows 上在 Git Bash 里运行，并确保 Docker Desktop 在运行。第一次运行会拉取 Caddy 镜像。
