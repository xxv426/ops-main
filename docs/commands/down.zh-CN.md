# ops down

[English](down.md)

```text
ops down <app>
```

停止一个应用，删除它的容器和网络。**数据保留**：`/srv/apps/<app>` 和命名卷都还在；路由也仍加载在 Caddy 里（请求会得到 502），直到删除应用目录并重新加载 Caddy。

## 执行流程

1. 要求 root，加载 `ops.conf`，检查应用存在。
2. 应用有 `compose.yaml` 时：
   1. `docker compose down`：停止并删除容器和项目自己的网络。命名卷保留（不带 `-v`）。
   2. 重写 `/var/lib/ops/edge.networks.yaml`，把运行中的 edge 从 `app-<app>` 断开。
   3. 删除网络 `app-<app>`（忽略错误）。
3. 输出应用已停止、路由会保留到删除为止。

静态网站（没有 compose 文件）没有东西可停，命令只输出日志。

## 常用形式

临时停止，再启动：

```bash
ops down umami
ops up umami
```

彻底下线一个应用：

```bash
ops backup vaultwarden                 # 最后一次备份
ops down vaultwarden
# 本地：git rm -r apps/vaultwarden，提交，scripts/sync.sh myserver
ops reload-caddy                       # 去掉路由
# 确认无误后：rm -rf /srv/apps/vaultwarden，docker volume rm <volumes>
```

把应用迁到另一台服务器：在这里 `ops backup <app>` 和 `ops down <app>`，然后在新服务器上 [`ops restore <app> --host <old OPS_HOST>`](restore.zh-CN.md)。
