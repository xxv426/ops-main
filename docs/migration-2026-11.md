# 服务器运维架构规划

> 2026 年 11 月把服务器从 xxvlab 仓库的 `infra/` 迁到 ops 时用的规划，保留其中的取舍理由和迁移记录。现行做法以 ops-starter 的 `docs/architecture.md` 为准。

状态：规划中，**尚未实施**。

本文分两部分：

- **第一部分：ops-starter 模板。** 一套通用的服务器运维代码，不包含任何具体服务器或应用。任何一台服务器都可以从它初始化，然后配置自己的备份、告警和应用。
- **第二部分：本次落地。** 用模板初始化 A1（运行 xxvlab 和 Vaultwarden）和 micro（运行监控、存放备份），并把现有的服务和备份迁移过去。

---

# 第一部分：ops-starter 模板

## 1. 概念

| 概念 | 是什么 | 例子 |
|---|---|---|
| **starter** | 通用模板仓库，只有平台代码、应用模板和示例，不含任何服务器信息 | `ops-starter` |
| **实例仓库** | 从 starter 初始化出来的仓库，**一台服务器对应一个**。在 starter 的基础上加入本机配置和本机应用 | `ops-main`、`ops-standby` |
| **服务器** | 运行一个实例仓库的机器 | A1、micro、以后的 B |
| **应用** | 实例仓库 `apps/` 下的一个目录 | xxvlab、vaultwarden |

```text
                 ops-starter（模板，通用）
                   │  初始化              ▲ 平台改进提交回模板
       ┌───────────┼───────────┐          │
       ▼           ▼           ▼          │
   ops-main       ops-standby    ops-b ───────┘
   apps: 1 2 3  apps: gatus  apps: 4 5 6
       │           │           │
   服务器 A1    服务器 micro  服务器 B
   自己的备份   自己的告警    自己的备份
   和告警配置                 和告警配置
```

每台服务器的流程都一样：用 starter 初始化 → 配置 restic 密码、备份仓库和告警 → 添加自己的应用。

## 2. 设计原则

1. **平台和应用分开。** 平台代码（`platform/`）只在 starter 里修改，实例仓库不改它。实例只增加 `ops.conf` 和 `apps/`。
2. **配置、数据、构建产物分开存放。** 配置来自 Git（`/opt/ops`），数据在 `/srv/apps`，静态网站在 `/srv/www`。
3. **服务器专有的信息不进 Git。** 密码、仓库地址、SMTP 凭据都在服务器的 `/etc/ops/` 下。
4. **每个应用自己声明要不要备份、备份到哪里。** 没有声明就拒绝启动。
5. **一台服务器只依赖它自己的配置。** 服务器之间唯一的联系是：一台可以把备份存到另一台（如 micro），一台可以监控另一台。

## 3. starter 仓库结构

```text
ops-starter/
├── platform/                    平台代码，实例仓库不修改
│   ├── bin/ops                  统一的运维命令
│   ├── lib/                     ops 的各个子命令
│   ├── edge/                    入口 Caddy
│   │   ├── compose.yaml
│   │   └── Caddyfile            公共片段 + import /etc/caddy/apps/*/site.caddy
│   ├── backup/
│   │   ├── run.sh               备份调度器
│   │   └── restore.sh           恢复和恢复演练
│   ├── alert/send.sh            通过 SMTP 发告警邮件
│   ├── docker/daemon.json       全局日志轮转
│   ├── bootstrap.sh             新服务器初始化
│   └── templates/               /etc/ops 下各配置文件的模板
│       ├── backup.env.example
│       └── alert.env.example
├── apps/
│   └── _template/               新应用模板
├── examples/                    可以直接复制的应用示例，不会被加载
│   ├── static-site/             纯静态网站（CI 发布到 /srv/www）
│   ├── sqlite-app/              单容器 + SQLite（如 Vaultwarden）
│   ├── postgres-app/            应用 + Postgres（如 Umami）
│   └── gatus/                   监控（部署在另一台服务器上）
├── ops.conf.example             实例配置模板
├── scripts/sync.sh              本地执行：把实例仓库同步到服务器
├── docs/                        通用文档：架构、运维、恢复、升级
├── VERSION                      平台版本号
└── CHANGELOG.md                 每个版本的变化和升级注意事项
```

starter 自己的 CI 用 `examples/` 做测试：`caddy validate`、`docker compose config`、`shellcheck`、`ops` 的单元测试。

## 4. 实例仓库

### 4.1 初始化

```bash
git clone git@github.com:xxv426/ops-starter.git ops-main
cd ops-main
git remote rename origin upstream             # 保留和 starter 的共同历史，以后能合并平台更新
git remote add origin git@github.com:xxv426/ops-main.git
cp ops.conf.example ops.conf                  # 填写本机信息
cp -r examples/sqlite-app apps/vaultwarden    # 添加应用
git add . && git commit -m "Initialize ops-main" && git push -u origin main
```

不用 GitHub 的 “Use this template” 按钮：那样生成的仓库和 starter 没有共同历史，以后合并平台更新会冲突。

### 4.2 实例仓库里实例自己的部分

```text
ops-main/
├── ops.conf          本机配置（进 Git，不含密钥）
├── apps/
│   ├── xxvlab/
│   └── vaultwarden/
└── docs/local/       本机特有的笔记（可选）
```

其他文件都来自 starter。

### 4.3 ops.conf

```bash
OPS_HOST=a1                     # 逻辑主机名：restic 快照的 --host、告警邮件标题都用它
OPS_ARCH=arm64                  # 检查镜像是否支持本机架构
RESOURCE_BUDGET_CPUS=2          # 所有应用资源上限合计不能超过它
RESOURCE_BUDGET_MEM=12g
BACKUP_TIME="30 19 * * *"       # 每晚备份的 cron 时间（服务器时区，通常是 UTC）
CHECK_TIME="0 21 * * 0"         # 每周校验和 prune 的时间
DEPLOY_USER=deploy              # 有静态网站时，CI 用这个用户发布；没有就留空
```

### 4.4 升级平台

starter 有改进时，在实例仓库里：

```bash
git fetch upstream
git merge upstream/main         # 实例只改了 ops.conf 和 apps/，通常不会冲突
# 看 CHANGELOG.md 里的升级注意事项
git push
scripts/sync.sh <服务器>
ssh <服务器> ops upgrade        # 按需要重建 edge、重新生成 cron 等
```

在某个实例里发现的平台问题，修复提交到 starter，再合并到各个实例，不直接改实例里的 `platform/`。

## 5. 应用规范

```text
apps/<应用>/
├── app.conf          给平台读的声明（必需）
├── compose.yaml      容器定义（必需，纯静态网站可以没有）
├── site.caddy        对外路由（有对外访问时必需）
├── backup-hook.sh    产出一份一致的数据（需要备份时必需）
├── restore-hook.sh   把数据放回去（可选，默认直接复制文件）
├── .env.example      需要哪些密钥（可选，不含真实值）
└── README.md         这个应用的说明和运维笔记（必需）
```

**app.conf**

```bash
APP_DOMAINS="vault.example.com"
HEALTH_URL="https://vault.example.com/alive"
BACKUP_TARGETS="micro b2"     # 必填：本机 backup.env 里定义过的目标名，或 none
BACKUP_KEEP="--keep-daily 14 --keep-weekly 8 --keep-monthly 12"
BACKUP_EXCLUDE=""
```

**compose.yaml 约定**

- 项目名就是应用名。
- 数据用绝对路径 `/srv/apps/<应用>/...` 绑定挂载；数据库可以用命名卷，备份读的是导出文件。
- 密钥用 `env_file: /srv/apps/<应用>/.env`。
- 对外服务加入外部网络 `app-<应用>`，不映射公网端口；管理端口只绑定 `127.0.0.1`。
- 内部服务（数据库）放进 `internal: true` 网络。
- 每个服务都设 `cpus` 和 `mem_limit`，镜像固定版本号。

**site.caddy**：只写本应用的站点块，可以用 edge 里定义的公共片段，上游写服务名。

**backup-hook.sh**：只负责把一致的数据写进平台提供的 `$STAGE`，失败时非零退出。上传、清理、告警都由平台负责。

**纯静态网站**：`site.caddy` 指向 `/srv/www/<应用>/current`，由网站自己的 CI 以 `DEPLOY_USER` 发布，`BACKUP_TARGETS=none`（可以从 Git 重新构建）。

## 6. 服务器目录与权限

| 路径 | 属主与权限 | 内容 |
|---|---|---|
| `/opt/ops/` | root，只读使用 | 实例仓库的内容，`sync.sh` 整体覆盖 |
| `/srv/apps/<应用>/` | root 700，子目录按容器用户设置 | `.env`（600）和数据 |
| `/srv/www/<站点>/` | `DEPLOY_USER` | `releases/` + `current` |
| `/etc/ops/restic-password` | root 600 | restic 仓库密码 |
| `/etc/ops/backup.env` | root 600 | 备份目标和凭据 |
| `/etc/ops/alert.env` | root 600 | SMTP 和收件人，心跳地址 |
| `/etc/cron.d/ops` | root | 由 `ops install-cron` 根据 `ops.conf` 生成 |
| `/var/backups/ops/` | root 700 | 备份暂存区，每次运行后清空 |
| `/var/log/ops/` | root | 日志，logrotate 轮转 |

作为备份存储的服务器（如 micro）另有：

| 路径 | 内容 |
|---|---|
| `/srv/backup/<客户端>/` | 某台服务器的 restic 仓库，属于该客户端专用的 SFTP 用户 |

## 7. 网络与访问

- **edge Caddy** 是唯一映射 80/443 的容器。挂载 `/opt/ops/platform/edge`、`/opt/ops/apps`、`/srv/www`（都只读），证书存在命名卷。一个实例只对应一台服务器，所以直接加载 `apps/*/site.caddy`。
- **每个应用一个网络** `app-<应用>`，由 `ops up` 创建，不属于任何 compose 项目。只有 edge 加入所有应用网络，应用之间互相访问不到。edge 加入哪些网络由 `ops` 扫描 `apps/` 生成。
- **改路由用 `ops reload-caddy`**：先 validate，通过才 reload。
- **端口**：对公网只开 22、80、443（TCP 和 UDP）。没有对外应用的服务器（如只做监控和备份存储的）只开 22。

## 8. 备份

### 8.1 备份目标

目标在每台服务器的 `/etc/ops/backup.env` 里定义，名字自己取，应用的 `BACKUP_TARGETS` 引用这些名字。支持 restic 的所有后端（SFTP、S3 兼容存储、REST server 等）。

```bash
# /etc/ops/backup.env
RESTIC_PASSWORD_FILE=/etc/ops/restic-password

TARGET_MICRO_REPOSITORY=sftp:backup-a1@10.0.0.20:/srv/backup/restic

TARGET_B2_REPOSITORY=s3:https://s3.<区域>.backblazeb2.com/<存储桶>/restic
TARGET_B2_AWS_ACCESS_KEY_ID=...
TARGET_B2_AWS_SECRET_ACCESS_KEY=...
```

规则：`TARGET_<名字>_REPOSITORY` 定义一个目标；同一前缀下的其他变量，在操作这个目标时去掉前缀导出。比如访问 `b2` 时导出 `AWS_ACCESS_KEY_ID`。这样平台不用为每种后端写专门的代码。

每台服务器用**自己的** restic 仓库：

- 存到另一台服务器时，每个客户端一个独立的 SFTP 用户和目录。
- 存到 B2 等对象存储时，每台服务器一个前缀，并且使用**只授权这个前缀**的密钥。

一台服务器被入侵，只能碰到它自己的备份。

### 8.2 流程

`ops install-cron` 根据 `ops.conf` 生成定时任务：

- **每晚**（`BACKUP_TIME`）：`ops backup --all`，用 flock 防止重复运行。
- **每周**（`CHECK_TIME`）：对每个目标执行 `restic prune` 和 `restic check --read-data-subset=5%`。

每个应用依次执行：

```text
① 读 app.conf；BACKUP_TARGETS=none 就跳过；目标没有在 backup.env 里定义就报错
② 清空 $STAGE，运行 backup-hook.sh
③ 复制 /srv/apps/<应用>/.env 到 $STAGE
④ 对每个目标：
     restic backup --host $OPS_HOST --tag <应用> $STAGE
     restic forget --tag <应用> --group-by tags $BACKUP_KEEP
⑤ 记录结果；任何一步失败都继续处理下一个应用
⑥ 清空 $STAGE
```

全部应用处理完后：有失败就发告警邮件，列出失败的应用和目标；不管成功与否，都发送心跳（见第 9 节）。

两个目标各自独立备份，不用 `restic copy`，一个仓库出问题不会影响另一个。

restic 使用官方静态二进制，版本固定在 starter 里（下载后校验 sha256），不用发行版的 apt 包。

### 8.3 恢复

- `ops restore <应用> [--from <目标>] [--snapshot ID] [--host <逻辑主机名>]`：停止应用 → 取出快照 → 运行 `restore-hook.sh` → 启动 → 检查 `HEALTH_URL`。`--host` 用于从另一台服务器的仓库恢复，比如迁移应用时。
- `ops restore-test <应用>`：恢复到临时目录，用不联网的临时容器检查。建议每季度对关键应用做一次。

### 8.4 不备份的内容

配置在 Git 里；静态网站可以重新构建；证书会自动重新签发；`/etc/ops/` 下的凭据存在密码管理器里。**restic 密码必须额外离线保存一份**，否则服务器丢失时备份打不开。

## 9. 告警与监控

告警分两层：服务器自己发现问题，主动发邮件；服务器自己宕机发不了邮件，由另一台服务器上的监控发现。

### 9.1 服务器自己发的告警

`/etc/ops/alert.env`：

```bash
SMTP_URL=smtps://smtp.example.com:465
SMTP_USER=...
SMTP_PASSWORD=...
ALERT_FROM=ops@example.com
ALERT_TO=you@example.com
HEARTBEAT_URL=                 # 可选，见 9.2
```

用 curl 的 SMTP 功能发邮件，不需要额外安装邮件程序。触发条件：

- 备份或每周校验失败。
- `ops up` 或 `ops reload-caddy` 失败。
- 资源上限合计超过预算。

`ops alert-test` 发一封测试邮件。

### 9.2 外部监控

在**另一台**服务器上用 `examples/gatus` 部署一个 Gatus 应用，检查：

- 各应用的 `HEALTH_URL`（连续 3 次失败告警）和证书有效期。
- **备份心跳**：各服务器每晚备份结束后，向 `HEARTBEAT_URL` 报告结果。超过 26 小时没收到，说明那台服务器可能宕机了，或者定时任务没有运行。

监控服务器本身就是一个普通的实例，Gatus 只是它的一个应用。

## 10. 新服务器的完整流程

1. 在云厂商创建实例，安全组开放 22（有对外应用的再开 80/443）。
2. 本地：按 4.1 初始化实例仓库，填写 `ops.conf`。
3. 本地：`scripts/sync.sh <服务器>`。
4. 服务器：`sudo /opt/ops/platform/bootstrap.sh`。安装 Docker、固定版本的 restic、全局日志轮转、BBR；创建目录；有 `DEPLOY_USER` 时创建发布用户；在 Oracle 镜像上处理它特有的 iptables 规则。
5. 服务器：`ops init`。依次引导你：
   - 写入 restic 密码（沿用已有的，或新生成一个，并提示你存进密码管理器）；
   - 按模板填写 `backup.env`，对每个目标检查连通性，仓库不存在时执行 `restic init`；
   - 填写 `alert.env`，发一封测试邮件。
6. 本地：在 `apps/` 下添加应用，提交，同步。
7. 服务器：对每个应用执行 `ops up <应用>`。
8. 服务器：`ops install-cron`，启用每晚备份和每周校验。
9. 手动执行一次 `ops backup --all`，确认收到心跳，没有告警邮件。
10. 在监控服务器的 Gatus 里加上这台服务器的应用和心跳。

## 11. 日常流程

| 操作 | 步骤 |
|---|---|
| 修改配置 | 本地修改实例仓库并提交 → `sync.sh` → 服务器上 `ops reload-caddy` 或 `ops up <应用>` |
| 新增应用 | 复制 `apps/_template` 或 `examples/*` → 填写 → 添加 DNS，等解析生效 → 提交、同步 → `ops up <应用>` → 在 Gatus 里加检查 |
| 下线应用 | `ops backup <应用>` → `ops down <应用>` → 删除目录，提交、同步 → `ops reload-caddy` → 确认后手动删除 `/srv/apps/<应用>` |
| 迁移应用到另一台服务器 | 旧服务器 `ops backup` + `ops down` → 把应用目录从旧实例仓库移到新实例仓库 → 新服务器 `ops restore <应用> --host <旧主机>` + `ops up` → 修改 DNS |
| 升级平台 | 见 4.4 |
| 重建服务器 | 第 10 节的 1–5 步 → 对每个应用 `ops restore` → `ops up` → 修改 DNS |

本地同步要用 Windows 自带的 OpenSSH，因为 SSH 私钥在密码管理器的 agent 里，Git Bash 自带的 ssh 连不上它。

## 12. ops 命令

| 命令 | 作用 |
|---|---|
| `ops init` | 初始化 `/etc/ops`：restic 密码、备份目标、告警 |
| `ops status` | 各应用状态、资源合计、最近一次备份、各目标占用空间 |
| `ops up / down / logs <应用>` | 启停和日志 |
| `ops reload-caddy` | 校验并热重载 Caddy |
| `ops backup <应用>` / `--all` | 立即备份 |
| `ops check` | 校验所有备份目标 |
| `ops restore` / `ops restore-test` | 恢复 / 恢复演练 |
| `ops install-cron` | 按 `ops.conf` 生成定时任务 |
| `ops alert-test` | 发测试告警邮件 |
| `ops upgrade` | 平台更新后执行必要的重建 |
| `ops version` | 显示平台版本 |

## 13. 护栏

- **资源预算**：`ops up` 和 CI 检查所有应用的资源上限合计不超过 `ops.conf` 里的预算。
- **镜像架构**：`ops up` 检查镜像包含 `OPS_ARCH`。
- **日志**：Docker 全局日志轮转（10 MB × 3）。
- **最小权限**：`DEPLOY_USER` 只能写 `/srv/www`；备份存储上每个客户端一个 SFTP 用户；CI 没有 root 权限。
- **密钥不进 Git**：starter 和实例仓库都只提交 `.example` 模板。

## 14. starter 不做的事

| 不做 | 原因 |
|---|---|
| 一个仓库管理多台服务器 | 每台服务器一个实例仓库，配置互不影响 |
| CI 自动部署服务器配置 | 需要 root 等价权限，不交给 CI；CI 只做校验 |
| 用 label 自动发现路由 | 需要把 Docker socket 挂进面向公网的容器 |
| 网站备用站和故障切换 | 静态网站可以从 Git 重建，只备份数据 |
| 网盘类备份目标（Google Drive、OneDrive、百度网盘） | 服务器上要存能访问整个网盘的令牌；百度网盘没有官方接口 |
| 管理云厂商资源和 DNS | 实例、安全组和 DNS 记录在控制台手动管理 |

---

# 第二部分：本次落地

## 15. 仓库和服务器规划

| 仓库 | 服务器 | 应用 | 备份 | 告警 |
|---|---|---|---|---|
| `ops-starter` | — | 模板 | — | — |
| `ops-main` | A1（4C24G，ARM） | xxvlab、vaultwarden | 目标 `micro`（SFTP，内网）和 `b2` | SMTP 邮件 + 向 micro 的 Gatus 发心跳 |
| `ops-standby` | micro（1C1G，x86） | gatus | `none`（Gatus 配置在 Git 里，状态不需要保留） | SMTP 邮件；Gatus 自己用 SMTP 发监控告警 |

三个仓库都是私有仓库。

micro 同时作为 A1 的备份存储：沿用现有的 `backup-a1` 用户和 `/srv/backup/restic` 仓库。

xxvlab 网站源码仓库只保留网站代码和发布流程，`infra/` 迁出。Actions 只发布到 A1 的 `/srv/www/xxvlab`，删除发布到 micro 的任务。

### 15.1 ops-main 的应用

| | xxvlab | vaultwarden |
|---|---|---|
| 基于 | `examples/postgres-app` + 静态网站 | `examples/sqlite-app` |
| 服务 | Umami、Postgres、Waline（未启用） | Vaultwarden |
| 域名 | xxvlab.com、www、stats、talk | vault |
| 数据 | `/srv/apps/xxvlab/{.env,waline/}`、命名卷 `xxvlab_umami-db`；静态文件 `/srv/www/xxvlab` | `/srv/apps/vaultwarden/{.env,data/}` |
| 备份目标 | `micro b2` | `micro b2`；hook 里另外在本机保留 7 个 tar 包 |
| 保留 | 7 天 / 4 周 / 6 月 | 14 天 / 8 周 / 12 月 |

### 15.2 ops.conf

```bash
# ops-main
OPS_HOST=a1
OPS_ARCH=arm64
RESOURCE_BUDGET_CPUS=2          # Oracle 免费额度：缩容到 2C12G 也不用改架构
RESOURCE_BUDGET_MEM=12g
BACKUP_TIME="30 19 * * *"       # 北京时间 03:30
CHECK_TIME="0 21 * * 0"
DEPLOY_USER=deploy

# ops-standby
OPS_HOST=micro
OPS_ARCH=amd64
RESOURCE_BUDGET_CPUS=0.5
RESOURCE_BUDGET_MEM=512m
DEPLOY_USER=
```

micro 不再运行网站备用站，也不对公网开放 80/443。Gatus 面板通过 SSH 隧道访问；接收 A1 心跳的端口只绑定内网 IP。

## 16. 沿用的凭据

不重新生成任何现有凭据，只换存放位置和变量名（2026-11-12 在 A1 上核对过变量名）：

| 现有 | 新位置 | 处理 |
|---|---|---|
| `/etc/xxvlab/restic-password` | `/etc/ops/restic-password` | 原样移动。micro 仓库继续用它；B2 的新仓库也用它初始化。密码管理器里的那份依然有效 |
| `backup.env` 的 `RESTIC_PASSWORD_FILE` | `/etc/ops/backup.env`，同名 | 值改为新路径 |
| `backup.env` 的 `RESTIC_REPOSITORY` | `TARGET_MICRO_REPOSITORY` | 值原样沿用 |
| `backup.env` 的 `APP_DIR` | — | 不再需要 |
| `b2.env` 的 `B2_BUCKET` | `TARGET_B2_REPOSITORY` 中的存储桶名 | 沿用现有存储桶，restic 仓库放在 `restic/` 前缀下 |
| `b2.env` 的 `B2_KEY_ID`、`B2_APP_KEY` | `TARGET_B2_AWS_ACCESS_KEY_ID`、`TARGET_B2_AWS_SECRET_ACCESS_KEY` | 值原样沿用。B2 的应用密钥可以直接当作 S3 密钥使用 |
| — | `TARGET_B2_REPOSITORY` 中的 S3 端点 | 新增，实施时从 B2 账户信息里读出 |
| — | `/etc/ops/alert.env` | 新增：SMTP 凭据由你直接在服务器上填写 |
| `/root/.ssh/id_ed25519`、`known_hosts` 里 micro 那一行、micro 上 `backup-a1` 的 `authorized_keys` | 不动 | |
| `/etc/xxvlab/b2-backup-passphrase` | — | 只用于解密 B2 上旧的 gpg 文件，见第 17 节 |

**现有快照：** micro 仓库里的 `nightly` 快照（xxvlab 的数据）改打 `xxvlab` 标签，由新的保留策略接管；`vaultwarden` 标签不变。新方案按 tag 分组清理，旧快照的主机名（`ubuntu`）不影响分组。

**需要实测的一点：** 现有 B2 密钥只验证过能列出文件。restic 清理旧快照需要删除权限，实施时用 `restic init` 和一次 `forget --prune` 测试，权限不够就需要你在 Backblaze 控制台重新生成。现有密钥能访问整个存储桶；以后加入第二台服务器时，再为每台服务器生成只授权各自前缀的密钥。

## 17. 旧备份的清理清单

新方案手动跑通（两个目标都有两个应用的快照，`restore-test` 通过）后，**立即移走旧的定时任务，再启用新的**，同一时间只有一套备份在运行。标为“删除”的脚本和配置先移到 `/root/legacy-backup/`（root 700），稳定一周后再彻底删除。

**A1**

| 项目 | 处理 |
|---|---|
| `/etc/cron.d/xxvlab-backup`、`/etc/cron.d/vaultwarden-backup` | 删除，由 `/etc/cron.d/ops` 取代 |
| `/usr/local/bin/backup-a1.sh` | 删除 |
| `/usr/local/bin/backup-vaultwarden.sh` 及 `.bak-20261105` | 删除 |
| `/usr/local/bin/b2-rclone`、Docker 镜像 `rclone/rclone:1.75.2` | 删除，新方案通过 S3 接口访问 B2 |
| `/etc/logrotate.d/vaultwarden-backup` | 删除，由 ops 的 logrotate 配置取代 |
| `/var/log/xxvlab-backup.log`、`/var/log/vaultwarden-backup.log` | 删除 |
| `/etc/xxvlab/backup.env`、`/etc/xxvlab/b2.env` | 值已并入 `/etc/ops/backup.env`，删除 |
| `/etc/xxvlab/restic-password` | 已移到 `/etc/ops/`，不留副本 |
| `/etc/xxvlab/b2-backup-passphrase` 和 B2 上的 `vaultwarden/*.tar.gz.gpg` | 一起处理：B2 新仓库积累满 14 天快照后，同时删除。在那之前都保留，旧文件仍可解密 |
| `/etc/xxvlab/` | 清空后删除 |
| apt 安装的 restic 0.12 | `apt remove restic` |
| `/var/backups/vaultwarden-staging/`、`/var/backups/xxvlab/` | 删除（如果存在） |
| `/var/backups/vaultwarden/` 里的 tar 包 | 保留目录，新 hook 继续在这里保留 7 份 |

**micro**：没有单独的备份脚本或定时任务，restic 仓库保留。

**仓库和文档**

| 项目 | 处理 |
|---|---|
| xxvlab 仓库的 `infra/` | 迁出后删除 |
| xxvlab 仓库的 `docs/deploy.md`、`docs/backup.md` | 运维部分并入 ops 仓库后删除或精简 |
| `R:\xxv\notes\host.md` | 改为指向 `ops-main/apps/vaultwarden/README.md` |

## 18. 实施步骤

每一步验证通过后再做下一步。

| 步骤 | 内容 | 影响 | 回滚 |
|---|---|---|---|
| **0. 准备**（你来操作） | Backblaze：确认 Caps & Alerts 上限为 $0，现有存储桶有“隐藏的文件保留 30 天”的生命周期规则。准备好发告警用的 SMTP 账号和授权码 | 无 | — |
| **1. 写 ops-starter** | 平台代码、`examples/`、文档、CI，用示例应用测试通过 | 无，不动服务器 | — |
| **2. 建 ops-main 和 ops-standby** | 从 starter 初始化；把 xxvlab、vaultwarden、Gatus 的现有配置整理成应用目录 | 无，不动服务器 | — |
| **3. micro 切换** | 同步 `ops-standby`，`bootstrap`、`ops init`；停止并删除备站 Caddy，关闭 80/443（安全列表和 iptables），删除 Cloudflare 的 `standby` 记录和 micro 上的 deploy 用户；`ops up gatus`，填写 SMTP，测试告警邮件 | 无（备站不对读者开放） | — |
| **4. A1 迁移目录和应用** | 先对两个应用各做一次备份。同步 `ops-main`，`bootstrap`；数据搬到 `/srv/apps/*`，`/srv/xxvlab` 搬到 `/srv/www/xxvlab`（过渡期保留旧路径的软链接）；按应用网络重新启动 edge 和两个应用，删除 `xxvlab-web` | Vaultwarden 和 Umami 各中断约 10 秒，全站约 2 秒 | 旧目录和旧 compose 保留到验证完成 |
| **5. A1 备份切换** | `ops init`：按第 16 节生成 `/etc/ops/*`，初始化 B2 仓库，micro 仓库升级到 v2 并改标签，测试邮件。手动 `ops backup --all` 和 `restore-test`。通过后按第 17 节清理，再 `ops install-cron` | 无 | 旧脚本在 `/root/legacy-backup/`，恢复旧 cron 即可 |
| **6. 网站仓库** | 删除 `infra/` 和 micro 发布任务，发布路径改为 `/srv/www/xxvlab`，删除过渡软链接 | 无 | — |
| **7. 监控和文档** | Gatus 加入 A1 两个应用的健康检查和备份心跳；更新文档和笔记；完整做一次恢复演练 | 无 | — |

## 19. 待确认

| 事项 | 默认 |
|---|---|
| 仓库名称 | `ops-starter`、`ops-main`、`ops-standby`，都是私有 |
