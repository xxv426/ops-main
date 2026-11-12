# shellcheck shell=bash
# Runs while the app is stopped: starts only the database, then loads the dump
# in one transaction, so a failed restore changes nothing. ops starts Umami.

gunzip -t "$RESTORE_DIR/umami.sql.gz"
compose up -d umami-db
for _ in $(seq 1 30); do
  if compose exec -T umami-db pg_isready -U umami -d umami </dev/null >/dev/null; then
    break
  fi
  sleep 2
done
gunzip -c "$RESTORE_DIR/umami.sql.gz" |
  compose exec -T umami-db psql -U umami -d umami -q -v ON_ERROR_STOP=1 --single-transaction >/dev/null
