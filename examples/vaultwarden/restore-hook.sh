# shellcheck shell=bash
# Runs while Vaultwarden is stopped. The old data stays beside the new until you
# delete it, in case the restore was a mistake.

data=$APP_DATA/data
if [[ -d $data ]]; then
  mv "$data" "$data.before-restore-$(date -u +%Y%m%dT%H%M%SZ)"
fi
install -d -m 700 "$data"
for item in db.sqlite3 attachments sends config.json rsa_key.pem rsa_key.pub.pem; do
  if [[ -e $RESTORE_DIR/$item ]]; then
    cp -a "$RESTORE_DIR/$item" "$data/"
  fi
done
echo "previous data kept in $data.before-restore-*; delete it once the restore is confirmed"
