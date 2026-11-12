# shellcheck shell=bash
# A consistent SQLite copy through the online backup API (safe while running),
# plus the files Vaultwarden keeps beside it. rsa_key* signs login tokens;
# without it every client has to log in again.

data=$APP_DATA/data
sqlite3 "$data/db.sqlite3" ".backup '$STAGE/db.sqlite3'"
result=$(sqlite3 "$STAGE/db.sqlite3" "PRAGMA integrity_check;")
if [[ $result != ok ]]; then
  echo "integrity check failed: $result" >&2
  exit 1
fi

for item in attachments sends config.json rsa_key.pem rsa_key.pub.pem; do
  if [[ -e $data/$item ]]; then
    cp -a "$data/$item" "$STAGE/"
  fi
done

# shellcheck disable=SC1091
source "$APP_DIR/app.conf"
if ((${LOCAL_COPIES:-0} > 0)); then
  local_dir=/var/backups/$APP
  install -d -m 700 "$local_dir"
  tar -C "$STAGE" --exclude ./.ops -czf "$local_dir/$APP-$(date -u +%Y%m%dT%H%M%SZ).tar.gz" .
  chmod 600 "$local_dir"/*.tar.gz
  find "$local_dir" -maxdepth 1 -name "$APP-*.tar.gz" -printf '%T@ %p\n' | sort -rn |
    tail -n +"$((LOCAL_COPIES + 1))" | cut -d' ' -f2- | xargs -r rm -f
fi
