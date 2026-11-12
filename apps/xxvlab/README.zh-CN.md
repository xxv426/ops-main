# xxvlab

[English](README.md)

https://xxvlab.com 背后的服务。

| 域名 | 内容 | 位置 |
|---|---|---|
| xxvlab.com | 静态 Astro 网站 | `/srv/www/xxvlab`，由 xxvlab 仓库的 GitHub Actions 以 `deploy` 用户发布 |
| www.xxvlab.com | 重定向到 xxvlab.com | |
| stats.xxvlab.com | Umami 统计 + Postgres | 卷 `xxvlab_umami-db-data` |
| talk.xxvlab.com | Waline 评论（启用前关闭） | `/srv/apps/xxvlab/waline/waline.sqlite` |

- 备份：Umami 用 `pg_dump`，Waline（存在时）用 SQLite 在线备份，备份到 `micro` 和 `b2`。网站可以从 Git 重新构建，所以不备份。
- 回滚网站：`ops rollback xxvlab` 列出版本，`ops rollback xxvlab <release>` 切换。
- Umami 登录：用户 `admin`；密码在密码管理器里。

## 启用评论

1. 创建一次数据库：

   ```bash
   install -d /srv/apps/xxvlab/waline
   curl -fsSL -o /srv/apps/xxvlab/waline/waline.sqlite \
     https://raw.githubusercontent.com/walinejs/waline/main/assets/waline.sqlite
   ```

   继续之前确认这个文件是 SQLite 数据库：
   `sqlite3 /srv/apps/xxvlab/waline/waline.sqlite .tables`。
2. 启动它：`cd /opt/ops/apps/xxvlab && docker compose --env-file /srv/apps/xxvlab/.env --profile comments up -d waline`。
3. 在 https://talk.xxvlab.com/ui/register 注册；第一个账户就是管理员。
4. 在 xxvlab 仓库的 GitHub variables 里设置 `PUBLIC_WALINE_SERVER_URL=https://talk.xxvlab.com`，然后重新运行它的发布 workflow。
