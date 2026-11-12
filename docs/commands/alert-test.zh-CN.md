# ops alert-test

[English](alert-test.md)

```text
ops alert-test
```

发一封测试告警邮件，用来检查 `/etc/ops/alert.env`。`ops init` 的最后一步就是运行它。

## 执行流程

1. 要求 root，加载 `ops.conf`。
2. 要求存在 `/etc/ops/alert.env`；没有时警告并失败。
3. 在子 shell 里加载 `alert.env`，要求有 `SMTP_URL`、`ALERT_FROM`、`ALERT_TO`。
4. 组装邮件：标题 `[ops <OPS_HOST>] test`，UTF-8 纯文本。
5. 用 curl 发送：`--ssl-reqd`（必须加密：465 端口用 `smtps://`，或 587 端口用 `smtp://` 经 STARTTLS 升级），`--sasl-ir`（一步完成 AUTH PLAIN；QQ 邮箱拒绝 curl 默认的两步方式），超时 60 秒。密码通过管道上的 netrc 文件传递，从不出现在命令行里。
6. 输出 `test alert sent; check the inbox of ALERT_TO`，或警告 `could not send alert email` 并以 1 退出。

真实告警走同一条路径：`ops backup` 发 `backup failed`，`ops check` 发 `backup check failed`。

## 常用形式

```bash
ops alert-test                   # 修改 /etc/ops/alert.env 或更换 SMTP 密码之后
```

失败时，手动带 `-v` 运行同样的 curl，查看 SMTP 交互过程。使用邮件服务商的授权码（应用专用密码），不要用账户密码。
