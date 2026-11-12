# Umami

Privacy-friendly web analytics with its own Postgres.

- First login is `admin` / `umami`. Change the password at once.
- Backups are `pg_dump` output; the database volume itself is never copied.
- A restore loads the dump in one transaction: all of it or none.
