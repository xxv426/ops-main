# Vaultwarden

[English](README.md)

兼容 Bitwarden 的密码管理器，使用 SQLite。

- 管理面板不对外：`ssh -L 8081:127.0.0.1:8081 <server>`，然后打开 `http://127.0.0.1:8081/admin`。
- 备份：SQLite 在线备份，加上附件、sends、`config.json` 和 `rsa_key*`，用 `PRAGMA integrity_check` 检查。另有 `LOCAL_COPIES` 份普通副本保存在 `/var/backups/vaultwarden`，恢复最快。
- `ops restore-test vaultwarden` 检查最新快照，并统计用户数和条目数。
- 恢复时会把原来的数据保留在 `data.before-restore-*`，直到你删除它。
- restic 密码除了这个密码库之外还要另存一处。如果服务器和密码库一起丢失，只存在这里的密码就拿不到了。
