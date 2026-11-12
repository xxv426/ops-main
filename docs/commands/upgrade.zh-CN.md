# ops upgrade

[English](upgrade.md)

```text
ops upgrade
```

新的平台版本合并进实例并同步之后，在服务器上让平台改动生效。可以重复运行。

## 执行流程

1. 要求 root，加载 `ops.conf`。
2. 重新把 `/usr/local/bin/ops` 链接到 `/opt/ops/platform/bin/ops`。
3. 有应用带 `site.caddy` 时：运行 `ops up edge`（edge 的 compose 文件或镜像有变化时重建它，重新生成网络覆盖文件）。
4. 存在 `/etc/cron.d/ops` 时：重新运行 [`ops install-cron`](install-cron.zh-CN.md)，让 cron 和 logrotate 文件的改动生效。
5. 输出 `upgraded to platform <VERSION>`。

它不重启应用，也不修改 `/etc/ops`。超出这些的步骤写在 `CHANGELOG.md` 对应版本下。

## 常用形式

完整的升级过程，从本地开始：

```bash
git fetch upstream
git merge upstream/main          # 读 CHANGELOG.md 里的额外步骤
platform/bin/ops lint
git push
scripts/sync.sh myserver
ssh myserver ops upgrade
ssh myserver ops status         # 看平台版本和 revision
```

如果新版本需要更新的 restic（`bootstrap.sh` 里的固定版本变了），还要运行 `sudo /opt/ops/platform/bootstrap.sh --web`。
