# shellcheck shell=bash
db=$RESTORE_DIR/db.sqlite3
result=$(sqlite3 "$db" "PRAGMA integrity_check;")
if [[ $result != ok ]]; then
  echo "integrity check failed: $result" >&2
  exit 1
fi
echo "users: $(sqlite3 "$db" "SELECT count(*) FROM users;"), items: $(sqlite3 "$db" "SELECT count(*) FROM ciphers;")"
test -f "$RESTORE_DIR/rsa_key.pem"
