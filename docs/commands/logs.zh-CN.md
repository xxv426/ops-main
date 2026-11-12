# ops logs

[English](logs.md)

```text
ops logs <app>|edge [docker compose logs options] [service…]
```

显示一个应用的容器（或入口 Caddy）最近 100 行日志。多余的参数原样传给 `docker compose logs`。

## 执行流程

1. 不要求 root，不读取 `ops.conf`；需要能访问 Docker（root 或 `docker` 组）。
2. `edge`：在 `platform/edge` 里执行 `docker compose logs --tail 100 <args>`。
3. 否则检查应用存在，然后对该应用执行 `docker compose logs --tail 100 <args>`，项目目录和 env 文件与 `ops up` 相同。

ops 自己的日志是另外的：`/var/log/ops/backup.log` 和 `/var/log/ops/check.log`（由 cron 写入）。

## 常用形式

```bash
ops logs vaultwarden                 # 最近 100 行
ops logs vaultwarden -f              # 持续跟踪
ops logs umami umami-db               # 多服务应用中的一个服务
ops logs umami --since 1h umami
ops logs edge -f                     # Caddy：证书、上游错误
ops logs edge --tail 500             # 后面的 --tail 覆盖默认的 100
```
