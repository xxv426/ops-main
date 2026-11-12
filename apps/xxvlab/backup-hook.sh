# shellcheck shell=bash
# Umami through pg_dump (consistent while running; --clean makes a restore
# replace existing objects), and Waline's SQLite through its online backup.

compose exec -T umami-db pg_dump -U umami -d umami --clean --if-exists </dev/null |
  gzip >"$STAGE/umami.sql.gz"
gunzip -t "$STAGE/umami.sql.gz"

if [[ -f $APP_DATA/waline/waline.sqlite ]]; then
  sqlite3 "$APP_DATA/waline/waline.sqlite" ".backup '$STAGE/waline.sqlite'"
fi
