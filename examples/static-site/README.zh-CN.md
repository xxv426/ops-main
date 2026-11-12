# 静态网站

[English](README.md)

由网站自己仓库的 CI 构建，由入口 Caddy 从 `/srv/www/<site>/current` 提供的网站。没有任何东西在容器里运行，也不备份任何东西：网站可以从 Git 重新构建。

1. 把这个目录复制为 `apps/<site>`。在 `site.caddy` 里把 `static-site` 替换为 `<site>`，设置域名，并设置带哈希资源的前缀（Astro 是 `/_astro/`，Vite 是 `/assets/`）。
2. 在服务器上，在 `ops.conf` 里设置 `DEPLOY_USER`，并运行 `bootstrap.sh --web --deploy-key '<CI public key>'`。
3. 把 `deploy.sh` 复制到网站的仓库，在 CI 里用那把密钥调用它：`deploy.sh deploy@<server> <site> dist`。
4. `ops up <site>` 加载路由。

用 `ops rollback <site>`（列出版本）和 `ops rollback <site> <release>` 回滚。
