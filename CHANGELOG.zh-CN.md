# 更新日志

[English](CHANGELOG.md)

升级实例：`git fetch upstream && git merge upstream/main`，然后同步，并在服务器上运行 `ops upgrade`。除此之外的步骤列在各版本下。

## 未发布

- 文档：`docs/commands/` 下每个命令一页，写明详细执行流程和日常常用形式；每个文档都有中文版（`*.zh-CN.md`）。
- `ops.conf`：去掉了 `OPS_ARCH`，架构在服务器上自动检测。请从你的 `ops.conf` 里删除这一行（`ops lint` 会提醒）。只有 `OPS_HOST` 和资源预算是必需的。
- `scripts/sync.sh` 在改动任何东西之前，先在服务器上检查 `/opt/ops` 属于同一个 `OPS_HOST`，并且新文件能通过 `ops lint`。`--force` 和 `--no-lint` 跳过这些检查。它把同步的提交记录在 `/opt/ops/.revision`，由 `ops status` 显示。
- 告警：用 `--sasl-ir` 发送 SMTP 凭据；QQ 邮箱拒绝 curl 默认的两步 AUTH PLAIN。

## 0.1.0

第一个版本：`ops` 命令，每个应用一个网络的入口 Caddy，按应用指定目标的 restic 备份，SMTP 告警和心跳，适用于 Ubuntu 和 Debian 的 bootstrap，以及静态网站、Vaultwarden、Umami 和 Gatus 的示例。
