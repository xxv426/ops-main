# shellcheck shell=bash
# Email alerts through SMTP, sent with curl so no mail software is needed.
#
# /etc/ops/alert.env:
#   SMTP_URL=smtps://smtp.example.com:465   (or smtp://host:587, upgraded with STARTTLS)
#   SMTP_USER=...
#   SMTP_PASSWORD=...
#   ALERT_FROM=ops@example.com
#   ALERT_TO=you@example.com

send_alert() {
  local subject=$1 body=$2
  if [[ ! -f $OPS_ETC/alert.env ]]; then
    warn "no $OPS_ETC/alert.env; alert not sent: $subject"
    return 1
  fi
  (
    # shellcheck disable=SC1091
    source "$OPS_ETC/alert.env"
    : "${SMTP_URL:?SMTP_URL is not set in alert.env}"
    : "${ALERT_FROM:?ALERT_FROM is not set in alert.env}"
    : "${ALERT_TO:?ALERT_TO is not set in alert.env}"
    host=${SMTP_URL#*://}
    host=${host%%[:/]*}
    # The password goes through a netrc on a pipe, never on the command line.
    printf 'From: %s\r\nTo: %s\r\nSubject: [ops %s] %s\r\nDate: %s\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n%s\r\n' \
      "$ALERT_FROM" "$ALERT_TO" "${OPS_HOST:-?}" "$subject" "$(date -R)" "$body" |
      curl -sS -m 60 --ssl-reqd --url "$SMTP_URL" \
        --netrc-file <(printf 'machine %s login %s password %s\n' "$host" "${SMTP_USER:-}" "${SMTP_PASSWORD:-}") \
        --mail-from "$ALERT_FROM" --mail-rcpt "$ALERT_TO" --upload-file -
  ) || {
    warn "could not send alert email: $subject"
    return 1
  }
}

cmd_alert_test() {
  require_root
  load_ops_conf
  send_alert "test" "This is a test alert from $OPS_HOST, sent by ops alert-test at $(date -u +%FT%TZ)." &&
    log "test alert sent; check the inbox of ALERT_TO"
}
