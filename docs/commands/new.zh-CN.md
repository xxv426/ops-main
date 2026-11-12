# ops new

[English](new.md)

```text
platform/bin/ops new <app>
```

从 `platform/templates/app` 创建 `apps/<app>`。在**本地的**实例仓库里运行，不要在服务器上运行：服务器的 `/opt/ops` 每次同步都会被整体替换。

## 执行流程

1. 不要求 root，不读取 `ops.conf`。
2. 名字必须匹配 `^[a-z0-9][a-z0-9-]*$`，且 `apps/<app>` 不能已存在。
3. 把 `platform/templates/app` 复制为 `apps/<app>`。
4. 把每个文件里的 `__APP__` 替换为应用名。
5. 输出 `Created apps/<app>. Fill in every file, then commit and sync.`

模板包含 `app.conf`、`compose.yaml`、`site.caddy`、`.env.example`、`backup-hook.sh`、`restore-hook.sh`、`verify-hook.sh` 和 `README.md`。每个文件写什么见 [docs/apps.zh-CN.md](../apps.zh-CN.md)。删掉应用用不到的文件（不对外的应用删 `site.caddy`，静态网站删 compose 文件，`BACKUP_TARGETS=none` 时删 hook）。

## 常用形式

```bash
platform/bin/ops new gitea                  # 从模板创建
cp -r examples/umami apps/umami             # 或从完整示例开始
platform/bin/ops lint                       # 提交前检查
git add apps/gitea && git commit -m "Add gitea" && scripts/sync.sh myserver
ssh myserver ops up gitea                  # 先创建 /srv/apps/gitea/.env 并配好 DNS
```
