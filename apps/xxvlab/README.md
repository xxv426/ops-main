# xxvlab

The services behind https://xxvlab.com.

| Domain | What | Where |
|---|---|---|
| xxvlab.com | Static Astro site | `/srv/www/xxvlab`, published by GitHub Actions in the xxvlab repository as `deploy` |
| www.xxvlab.com | Redirect to xxvlab.com | |
| stats.xxvlab.com | Umami analytics + Postgres | volume `xxvlab_umami-db-data` |
| talk.xxvlab.com | Waline comments (off until enabled) | `/srv/apps/xxvlab/waline/waline.sqlite` |

- Backups: Umami as `pg_dump`, Waline (when present) as a SQLite online backup,
  to `micro` and `b2`. The site is rebuilt from Git, so it is not backed up.
- Roll the site back: `ops rollback xxvlab` lists releases,
  `ops rollback xxvlab <release>` switches.
- Umami login: user `admin`; the password is in your password manager.

## Enabling comments

1. Create the database once:

   ```bash
   install -d /srv/apps/xxvlab/waline
   curl -fsSL -o /srv/apps/xxvlab/waline/waline.sqlite \
     https://raw.githubusercontent.com/walinejs/waline/main/assets/waline.sqlite
   ```

   Check that the file is a SQLite database before going on:
   `sqlite3 /srv/apps/xxvlab/waline/waline.sqlite .tables`.
2. Start it: `cd /opt/ops/apps/xxvlab && docker compose --env-file /srv/apps/xxvlab/.env --profile comments up -d waline`.
3. Register at https://talk.xxvlab.com/ui/register; the first account is the admin.
4. Set `PUBLIC_WALINE_SERVER_URL=https://talk.xxvlab.com` in the xxvlab repository's
   GitHub variables and run its deploy workflow again.
