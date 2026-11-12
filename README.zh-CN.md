# ops-starter

[English](README.md)

一套小而通用的工具，用 Docker Compose 在一台服务器上运行几个自托管应用：一个 Caddy 挡在所有应用前面，每个应用一个网络，每个应用自己声明的 restic 备份，以及邮件告警。

这个仓库本身不包含任何服务器或应用。每台服务器从它生成一个自己的**实例仓库**，实例只增加 `ops.conf`、该服务器在 `apps/` 下的应用，以及记录这台服务器情况的 `INSTANCE.md`。平台的改进在这里完成，再合并到各个实例；实例从不修改 starter 的文件，所以这些合并不会冲突。

```text
ops-starter ──► ops-main     (服务器 A：应用 1、2、3)
            ──► ops-standby  (服务器 B：应用 4、5、6)
```

## 服务器能得到什么

| 组成 | 作用 |
|---|---|
| `ops` 命令 | 启停应用、安全地重载 Caddy、备份、恢复、告警 |
| 入口 Caddy | 唯一占用 80/443 端口的容器；为每个应用的域名提供 HTTPS |
| 每个应用一个网络 | 应用之间互相访问不到，只有入口能访问它们 |
| 备份 | restic 备份到各应用在 `app.conf` 里列出的目标；每晚备份，每周清理和校验 |
| 告警 | 任何失败都通过 SMTP 发邮件；可选向外部监控发送心跳 |
| 护栏 | 资源预算、固定版本的镜像、除经过 Caddy 外不开放公网端口 |

服务器上各部分的位置：

| 路径 | 内容 | 来源 |
|---|---|---|
| `/opt/ops` | 本仓库的文件（经由实例仓库） | Git，每次同步整体替换 |
| `/srv/apps/<app>/` | 应用的数据和 `.env` | 应用；按其声明备份 |
| `/srv/www/<site>/` | 静态网站 | CI；可从 Git 重新构建 |
| `/etc/ops/` | restic 密码、备份目标、SMTP | 你在服务器上填写；从不进 Git |

## 初始化一台新服务器

在本地：

```bash
git clone <ops-starter url> ops-<server>
cd ops-<server>
git remote rename origin upstream        # 保留 starter 的历史，以后好合并
git remote add origin <new private repository url>
cp ops.conf.example ops.conf             # 填写它；关于服务器的笔记写在 INSTANCE.md
cp -r examples/vaultwarden apps/vaultwarden   # 或：platform/bin/ops new <app>
# 编辑应用的文件，然后：
git add -A && git commit -m "Initialize ops-<server>" && git push -u origin main
scripts/sync.sh <ssh-host>
```

在服务器上，以 root 身份：

```bash
/opt/ops/platform/bootstrap.sh --web     # 提供网站时加 --web；CI 发布见 --deploy-key
ops init --generate-password             # 或把已有密码写入 /etc/ops/restic-password
# ops init 提示时填写 /etc/ops/backup.env 和 /etc/ops/alert.env，然后：
ops init --init-missing                  # 检查或创建每个备份仓库，发送测试邮件
ops up <app>                             # 每个应用执行一次
ops install-cron
ops backup --all                         # 手动跑一次
```

把 restic 密码保存在密码管理器里，**并且**离线保存一份。没有它，任何备份都打不开。

## 日常操作

| 任务 | 步骤 |
|---|---|
| 修改应用 | 编辑、提交、`scripts/sync.sh <host>`，然后 `ops up <app>`（只改路由时用 `ops reload-caddy`） |
| 新增应用 | `platform/bin/ops new <app>` 或复制一个示例；添加 DNS 并等待解析生效；提交、同步、`ops up <app>` |
| 下线应用 | `ops backup <app>`、`ops down <app>`、删除目录、提交、同步、`ops reload-caddy` |
| 恢复 | `ops restore <app>`（第一个目标的最新快照）、`--from <target>`、`--snapshot <id>` |
| 演练 | 每季度 `ops restore-test <app>` |
| 把应用迁到另一台服务器 | 在旧服务器 `ops backup` 和 `ops down`；把目录从一个实例仓库移到另一个；在新服务器 `ops restore <app> --host <old host>` 和 `ops up`；切换 DNS |
| 升级平台 | 在实例里：`git fetch upstream && git merge upstream/main`，读 `CHANGELOG.md`，推送、同步、`ops upgrade` |

不带参数运行 `ops` 可以看到所有命令。

## 文档

- [docs/architecture.zh-CN.md](docs/architecture.zh-CN.md)：各部分如何组合，以及为什么这样设计
- [docs/apps.zh-CN.md](docs/apps.zh-CN.md)：如何编写一个应用目录
- [docs/commands/README.zh-CN.md](docs/commands/README.zh-CN.md)：每个 `ops` 命令的详细执行流程和常用形式
- [examples/](examples)：静态网站、Vaultwarden（SQLite）、Umami（Postgres）、Gatus（监控）
