# Umami

[English](README.md)

注重隐私的网站统计，自带 Postgres。

- 首次登录是 `admin` / `umami`。立即修改密码。
- 备份的是 `pg_dump` 的输出；从不直接复制数据库卷。
- 恢复时在一个事务里加载导出文件：要么全部成功，要么什么都不改。
