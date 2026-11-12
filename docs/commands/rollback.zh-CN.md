# ops rollback

[English](rollback.md)

```text
ops rollback <site>
ops rollback <site> <release>
```

列出静态网站的各个版本，或把网站切回其中一个。静态网站由 CI 用 `deploy.sh` 发布到 `/srv/www/<site>/releases/<release>`，`/srv/www/<site>/current` 指向线上版本；`deploy.sh` 保留最近 5 个版本。

## 执行流程

1. 要求 root。不读取 `ops.conf`。
2. 要求存在 `/srv/www/<site>/releases`。
3. **不带版本：** 输出 `current` 指向哪里，并按从新到旧列出各版本。不做任何改动。
4. **带版本：** 要求存在 `releases/<release>`，新建软链接 `current.next`，再用 `mv -T` 把它改名覆盖 `current`。切换是原子的，Caddy 不会看到目录缺失。输出新的指向。

不需要重载 Caddy：Caddy 提供的是 `/srv/www/<site>/current`，每次请求都会跟随链接。下一次 CI 发布会再把 `current` 切到新版本，所以要在下次推送前在 Git 里修好网站。

## 常用形式

```bash
ops rollback blog                            # 列出
ops rollback blog 20261110083015-1a2b3c4   # 切回（名字是 <UTC 时间>-<提交号>）
```
