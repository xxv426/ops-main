# ops up

[English](up.md)

```text
ops up <app>
ops up edge
```

启动一个应用，或让它的改动生效：拉取镜像、（重新）创建配置有变化的容器、把 edge 接入它的网络，应用有路由时重新加载 Caddy。可以重复运行。`ops up edge` 只启动或更新入口 Caddy。

## 执行流程：`ops up <app>`

1. 要求 root，加载 `ops.conf`。
2. **应用存在**：名字必须匹配 `^[a-z0-9][a-z0-9-]*$`，且存在 `apps/<app>/app.conf`。
3. **备份目标**：加载 `app.conf`。`BACKUP_TARGETS` 必须设置（目标名或 `none`）。不是 `none` 时，`/etc/ops/backup.env` 必须存在且定义了所列的每个目标。
4. **资源预算**：累加所有应用所有服务的 `cpus` 和 `mem_limit`（有应用带路由时也算上 edge）。任一服务缺少其中一项，或合计超过 `RESOURCE_BUDGET_CPUS` / `RESOURCE_BUDGET_MEM`，就停止。
5. 创建 `/srv/apps/<app>`（700）。
6. 应用有 `compose.yaml` 时：
   1. **密钥**：存在 `.env.example` 时，`/srv/apps/<app>/.env` 必须存在，并为其中每个键给出非空值。
   2. 网络 `app-<app>` 不存在时创建。
   3. `docker compose pull --quiet`。
   4. **架构**：每个镜像都必须是本机 CPU（`amd64` 或 `arm64`）的版本；不匹配时在启动任何东西之前停止。
   5. `docker compose up -d --remove-orphans`：只重建配置或镜像有变化的容器，并删除已不存在的服务的容器。
   6. 重写 `/var/lib/ops/edge.networks.yaml`；edge 在运行时，不重启地把它接入 `app-<app>`。
7. 应用有 `site.caddy` 时：运行 [`ops reload-caddy`](reload-caddy.zh-CN.md)（先校验再重载；edge 没在运行就启动它）。
8. 输出 `<app> is up`。

针对应用的 compose 命令总是带 `--project-directory apps/<app>`、`-f apps/<app>/compose.yaml`，以及 `--env-file /srv/apps/<app>/.env`（还没有 `.env` 时用 `.env.example`）。

## 执行流程：`ops up edge`

1. 要求 root，加载 `ops.conf`。
2. 为每个有 compose 文件的应用创建网络 `app-<app>`。
3. 写入 `/var/lib/ops/edge.networks.yaml`（让 edge 加入所有应用网络）。
4. 在 `platform/edge` 里带上这个覆盖文件执行 `docker compose up -d --remove-orphans`。

不做应用检查、预算检查和重载：edge 本身有变化或没在运行时使用。

## 失败

| 信息 | 处理 |
|---|---|
| `no such app` | 先同步；目录必须存在于 `/opt/ops/apps` |
| `set BACKUP_TARGETS in app.conf` | 填写目标名或 `none` |
| `backup target 'x' is not defined` | 在 `/etc/ops/backup.env` 里添加 `TARGET_X_REPOSITORY`，或改正名字 |
| `every service needs cpus and mem_limit` / `exceed the budget` | 补上限制，或调低 |
| `needs /srv/apps/<app>/.env` / `has no value for: …` | 按 `.env.example` 创建该文件（600）并填写 |
| `image … is amd64, but this server is arm64` | 换一个有 arm64 版本的镜像或标签 |
| `Caddy configuration is invalid` | 容器已更新，路由没有；修复 `site.caddy`，同步，`ops reload-caddy` |

## 常用形式

```bash
ops up vaultwarden          # 改了它的 compose.yaml、.env 或镜像标签之后
ops up umami
ops up edge                 # edge 有改动，或 Caddy 没在运行
for app in umami vaultwarden; do ops up "$app"; done   # 所有应用，例如重建服务器后
```

更新镜像：在 `compose.yaml` 里改标签，提交，同步，`ops up <app>`。
