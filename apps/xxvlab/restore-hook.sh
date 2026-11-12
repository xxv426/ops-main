# shellcheck shell=bash
# Runs with the app stopped. Loads the Umami dump in one transaction (all or
# nothing) and puts Waline's database back if the backup has one.

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

if [[ -f $RESTORE_DIR/waline.sqlite ]]; then
  install -d "$APP_DATA/waline"
  cp "$RESTORE_DIR/waline.sqlite" "$APP_DATA/waline/waline.sqlite"
fi
