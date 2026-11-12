# ops reload-caddy

[English](reload-caddy.md)

```text
ops reload-caddy
```

校验 Caddy 配置，只有通过时才在运行中的 edge 里热重载，不断开现有连接。修改 `site.caddy`（或删除应用）并同步之后使用。

为什么不直接 `caddy reload`：重载失败时坏文件仍留在磁盘上，下次 edge 重启会拒绝启动，所有网站一起下线。先校验，坏文件当场就会被发现。

## 执行流程

1. 要求 root，加载 `ops.conf`。
2. **edge 没在运行？** 有应用带 `site.caddy` 时启动 edge（[`ops up edge`](up.zh-CN.md)）后返回；否则什么都不做直接返回。
3. 在 edge 容器里执行 `caddy validate --config /etc/caddy/Caddyfile`。Caddyfile 会 import 每个 `/etc/ops-apps/*/site.caddy`，也就是只读挂载的 `/opt/ops/apps`，所以校验的正是刚同步的内容。失败时停止，提示 `Caddy configuration is invalid; nothing was reloaded`，正在运行的配置保持不变。
4. 用同一个文件执行 `caddy reload`。
5. 输出 `Caddy reloaded`。

对带 `site.caddy` 的应用，`ops up <app>` 也会执行同样的步骤。`scripts/sync.sh` 已经运行过 `ops lint`（它在临时容器里校验配置），所以这里很少会失败。

## 常用形式

```bash
ops reload-caddy                 # 改路由后：提交、同步，然后执行它
ops logs edge --since 5m         # 新域名的证书签发情况
```

新域名要先添加 DNS 记录，等解析生效后再第一次重载，否则 Let's Encrypt 验证会反复失败，导致该域名被限流。
