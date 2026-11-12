# shellcheck shell=bash
dump=$RESTORE_DIR/umami.sql.gz
gunzip -t "$dump"
gunzip -c "$dump" | grep -q "PostgreSQL database dump complete"
echo "umami tables: $(gunzip -c "$dump" | grep -c '^CREATE TABLE')"
if [[ -f $RESTORE_DIR/waline.sqlite ]]; then
  [[ $(sqlite3 "$RESTORE_DIR/waline.sqlite" "PRAGMA integrity_check;") == ok ]]
  echo "waline: integrity ok"
fi
