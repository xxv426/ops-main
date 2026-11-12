# shellcheck shell=bash
# Backups with restic. Each app declares its targets in app.conf; this server
# defines what each target name means in /etc/ops/backup.env:
#
#   TARGET_<NAME>_REPOSITORY=<restic repository>
#   TARGET_<NAME>_<VAR>=<value>     exported as <VAR> while restic talks to <name>
#
# so any restic backend works without code for it here.

RESTIC=${RESTIC:-restic}
RESTIC_LOCK_WAIT=${RESTIC_LOCK_WAIT:-10m}

load_backup_env() {
  [[ -n ${BACKUP_ENV_LOADED:-} ]] && return 0
  [[ -f $OPS_ETC/backup.env ]] || die "missing $OPS_ETC/backup.env (run ops init)"
  # shellcheck disable=SC1091
  source "$OPS_ETC/backup.env"
  : "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE is not set in backup.env}"
  [[ -r $RESTIC_PASSWORD_FILE ]] || die "cannot read $RESTIC_PASSWORD_FILE"
  export RESTIC_PASSWORD_FILE
  BACKUP_ENV_LOADED=1
}

target_var_prefix() { printf 'TARGET_%s_' "${1^^}"; }

target_defined() {
  local var
  var="$(target_var_prefix "$1")REPOSITORY"
  [[ -n ${!var:-} ]]
}

defined_targets() {
  local var name
  for var in $(compgen -v TARGET_); do
    [[ $var == *_REPOSITORY ]] || continue
    name=${var#TARGET_}
    name=${name%_REPOSITORY}
    echo "${name,,}"
  done
}

# Runs restic against one target. The subshell keeps one target's credentials
# out of every other restic call.
restic_on() {
  local target=$1 prefix repo_var
  shift
  prefix=$(target_var_prefix "$target")
  repo_var=${prefix}REPOSITORY
  (
    for var in $(compgen -v "$prefix"); do
      [[ $var == "$repo_var" ]] && continue
      export "${var#"$prefix"}=${!var}"
    done
    export RESTIC_REPOSITORY=${!repo_var}
    exec "$RESTIC" "$@"
  )
}

# Sources a hook in a subshell with strict mode and the helpers it may use.
# Extra arguments are VAR=value pairs exported to the hook.
run_hook() {
  local app=$1 hook=$2
  shift 2
  local file
  file=$(app_dir "$app")/$hook
  [[ -f $file ]] || die "$app has no $hook"
  (
    set -euo pipefail
    APP=$app
    APP_DIR=$(app_dir "$app")
    APP_DATA=$(app_data "$app")
    export APP APP_DIR APP_DATA OPS_ROOT
    for pair in "$@"; do
      export "${pair?}"
    done
    compose() { app_compose "$APP" "$@"; }
    cd "$APP_DIR"
    # shellcheck disable=SC1090
    source "$file"
  )
}

# Reports one app's result to HEARTBEAT_URL from alert.env, if set. {host},
# {app} and {success} in the URL are filled in; HEARTBEAT_TOKEN, if set, is sent
# as a bearer token on stdin so it never shows up in the process list.
send_heartbeat() {
  local app=$1 success=$2
  [[ -f $OPS_ETC/alert.env ]] || return 0
  (
    # shellcheck disable=SC1091
    source "$OPS_ETC/alert.env"
    [[ -n ${HEARTBEAT_URL:-} ]] || exit 0
    url=${HEARTBEAT_URL//\{host\}/$OPS_HOST}
    url=${url//\{app\}/$app}
    url=${url//\{success\}/$success}
    if [[ -n ${HEARTBEAT_TOKEN:-} ]]; then
      curl -fsS -m 20 -X POST -H @- -o /dev/null "$url" <<<"Authorization: Bearer $HEARTBEAT_TOKEN"
    else
      curl -fsS -m 20 -X POST -o /dev/null "$url"
    fi
  ) || warn "heartbeat for $app failed"
}

# Backs up one app to each of its targets. Sets BACKUP_FAILED to the targets
# that failed, or "hook" when the app could not produce its data.
backup_app() {
  local app=$1 stage target exclude=() pattern failed=()
  BACKUP_FAILED=""
  load_app_conf "$app"
  stage=$OPS_STAGE_ROOT/$app
  rm -rf "$stage"
  install -d -m 700 "$stage" "$stage/.ops"

  if ! run_hook "$app" backup-hook.sh STAGE="$stage"; then
    warn "$app: backup-hook.sh failed"
    rm -rf "$stage"
    BACKUP_FAILED=hook
    return
  fi
  if [[ -f $(app_data "$app")/.env ]]; then
    install -m 600 "$(app_data "$app")/.env" "$stage/.ops/env"
  fi

  for pattern in $BACKUP_EXCLUDE; do
    exclude+=(--exclude "$pattern")
  done
  for target in $BACKUP_TARGETS; do
    if ! target_defined "$target"; then
      warn "$app: target $target is not defined in backup.env"
      failed+=("$target")
      continue
    fi
    # BACKUP_KEEP holds several options, so it is split on purpose.
    # shellcheck disable=SC2086
    if restic_on "$target" backup --retry-lock "$RESTIC_LOCK_WAIT" --host "$OPS_HOST" --tag "$app" \
      "${exclude[@]}" "$stage" &&
      restic_on "$target" forget --retry-lock "$RESTIC_LOCK_WAIT" --tag "$app" --group-by tags $BACKUP_KEEP; then
      log "$app -> $target: ok"
    else
      warn "$app -> $target: failed"
      failed+=("$target")
    fi
  done
  rm -rf "$stage"
  BACKUP_FAILED=${failed[*]}
}

cmd_backup() {
  require_root
  load_ops_conf
  load_backup_env
  local apps=() app summary=() status_dir
  if [[ ${1:-} == --all ]]; then
    mapfile -t apps < <(list_apps)
  else
    require_app "${1:?usage: ops backup <app>|--all}"
    apps=("$1")
  fi

  install -d -m 700 "$OPS_STAGE_ROOT"
  status_dir=$OPS_STATE/backup
  install -d -m 755 "$status_dir"
  exec 9>"$OPS_STAGE_ROOT/.lock"
  flock -n 9 || die "another backup or check is running"

  for app in "${apps[@]}"; do
    load_app_conf "$app"
    if [[ -z $BACKUP_TARGETS ]]; then
      warn "$app: BACKUP_TARGETS is not set; skipping"
      summary+=("$app: BACKUP_TARGETS is not set")
      continue
    fi
    [[ $BACKUP_TARGETS == none ]] && continue
    log "backing up $app"
    backup_app "$app"
    if [[ -z $BACKUP_FAILED ]]; then
      echo "$(date -u +%FT%TZ) ok" >"$status_dir/$app.status"
      send_heartbeat "$app" true
    else
      echo "$(date -u +%FT%TZ) FAILED: $BACKUP_FAILED" >"$status_dir/$app.status"
      summary+=("$app: failed ($BACKUP_FAILED)")
      send_heartbeat "$app" false
    fi
  done

  if ((${#summary[@]})); then
    send_alert "backup failed" "$(printf '%s\n' "${summary[@]}")

Details are in $OPS_LOG_DIR/backup.log on $OPS_HOST."
    die "backup finished with failures"
  fi
  log "backup finished"
}

# Weekly: prune unreferenced data, then read back a different 5% each time.
cmd_check() {
  require_root
  load_ops_conf
  load_backup_env
  local target failed=()
  install -d -m 700 "$OPS_STAGE_ROOT"
  exec 9>"$OPS_STAGE_ROOT/.lock"
  flock 9
  for target in $(defined_targets); do
    log "checking $target"
    if restic_on "$target" prune --retry-lock "$RESTIC_LOCK_WAIT" &&
      restic_on "$target" check --retry-lock "$RESTIC_LOCK_WAIT" --read-data-subset=5%; then
      log "$target: ok"
    else
      warn "$target: failed"
      failed+=("$target")
    fi
  done
  if ((${#failed[@]})); then
    send_alert "backup check failed" "restic prune or check failed on $OPS_HOST for: ${failed[*]}"
    die "check failed for: ${failed[*]}"
  fi
  log "check finished"
}

backup_usage() {
  load_backup_env
  local target app bytes count
  for target in $(defined_targets); do
    bytes=$(restic_on "$target" stats --mode raw-data --json 2>/dev/null | jq -r '.total_size // empty')
    echo "$target: $([[ -n $bytes ]] && human_bytes "$bytes" || echo unavailable)"
    for app in $(list_apps); do
      load_app_conf "$app"
      [[ " $BACKUP_TARGETS " == *" $target "* ]] || continue
      count=$(restic_on "$target" snapshots --tag "$app" --json 2>/dev/null | jq 'length')
      echo "  $app: ${count:-?} snapshots"
    done
  done
}

parse_restore_args() {
  RESTORE_APP=${1:?usage: ops restore <app> [--from target] [--snapshot id] [--host name] [--restore-env]}
  shift
  RESTORE_TARGET=""
  RESTORE_SNAPSHOT=latest
  RESTORE_HOST=$OPS_HOST
  RESTORE_ENV=0
  while (($#)); do
    case $1 in
      --from) RESTORE_TARGET=${2:?}; shift 2 ;;
      --snapshot) RESTORE_SNAPSHOT=${2:?}; shift 2 ;;
      --host) RESTORE_HOST=${2:?}; shift 2 ;;
      --restore-env) RESTORE_ENV=1; shift ;;
      *) die "unknown option: $1" ;;
    esac
  done
  require_app "$RESTORE_APP"
  load_app_conf "$RESTORE_APP"
  [[ -n $RESTORE_TARGET ]] || RESTORE_TARGET=${BACKUP_TARGETS%% *}
  [[ -n $RESTORE_TARGET && $RESTORE_TARGET != none ]] || die "$RESTORE_APP has no backup target"
  target_defined "$RESTORE_TARGET" || die "target $RESTORE_TARGET is not defined in backup.env"
}

# Restores one snapshot into a new temporary directory. Sets RESTORE_ROOT (the
# temporary directory) and RESTORE_DIR (where the backed-up files are inside it).
restore_to_temp() {
  local app=$1 target=$2 snapshot=$3 host=$4 path
  if [[ $snapshot == latest ]]; then
    snapshot=$(restic_on "$target" snapshots --host "$host" --tag "$app" --json |
      jq -r 'sort_by(.time) | last | .id // empty')
    [[ -n $snapshot ]] || die "no snapshot of $app from host $host on $target"
  fi
  path=$(restic_on "$target" snapshots "$snapshot" --json | jq -r '.[0].paths[0] // empty')
  [[ -n $path ]] || die "cannot read snapshot $snapshot on $target"
  install -d -m 700 "$OPS_STAGE_ROOT"
  RESTORE_ROOT=$(mktemp -d "$OPS_STAGE_ROOT/restore-$app.XXXXXX")
  log "restoring snapshot ${snapshot:0:8} of $app from $target"
  restic_on "$target" restore "$snapshot" --target "$RESTORE_ROOT" >/dev/null
  RESTORE_DIR=$RESTORE_ROOT$path
}

cmd_restore() {
  require_root
  load_ops_conf
  load_backup_env
  parse_restore_args "$@"
  local app=$RESTORE_APP
  restore_to_temp "$app" "$RESTORE_TARGET" "$RESTORE_SNAPSHOT" "$RESTORE_HOST"
  # shellcheck disable=SC2064
  trap "rm -rf '$RESTORE_ROOT'" EXIT

  install -d -m 700 "$(app_data "$app")"
  if [[ -f $RESTORE_DIR/.ops/env ]]; then
    if [[ ! -f $(app_data "$app")/.env || $RESTORE_ENV == 1 ]]; then
      install -m 600 "$RESTORE_DIR/.ops/env" "$(app_data "$app")/.env"
      log "restored $(app_data "$app")/.env"
    else
      log "kept the existing .env (pass --restore-env to replace it)"
    fi
  fi

  if app_has_compose "$app"; then
    app_compose "$app" down
    ensure_network "$(app_network "$app")"
  fi
  run_hook "$app" restore-hook.sh RESTORE_DIR="$RESTORE_DIR" || die "$app: restore-hook.sh failed"
  cmd_up "$app"
  check_health "$app" || true
  log "$app restored"
}

cmd_restore_test() {
  require_root
  load_ops_conf
  load_backup_env
  parse_restore_args "$@"
  local app=$RESTORE_APP
  restore_to_temp "$app" "$RESTORE_TARGET" "$RESTORE_SNAPSHOT" "$RESTORE_HOST"
  # shellcheck disable=SC2064
  trap "rm -rf '$RESTORE_ROOT'" EXIT
  echo "files:"
  (cd "$RESTORE_DIR" && find . -type f -printf '  %p  %s bytes\n' | sort)
  if [[ -f $(app_dir "$app")/verify-hook.sh ]]; then
    run_hook "$app" verify-hook.sh RESTORE_DIR="$RESTORE_DIR" || die "$app: verify-hook.sh failed"
    log "$app: verify-hook.sh passed"
  fi
  log "$app: restore test passed ($RESTORE_TARGET)"
}

# Checks HEALTH_URL from the server itself. Apps behind the edge are reached
# through 127.0.0.1, because some clouds cannot route to their own public IP.
check_health() {
  local app=$1 host resolve=()
  load_app_conf "$app"
  [[ -n $HEALTH_URL ]] || return 0
  if app_has_site "$app" && [[ $HEALTH_URL == https://* ]]; then
    host=${HEALTH_URL#https://}
    host=${host%%[/:]*}
    resolve=(--resolve "$host:443:127.0.0.1")
  fi
  for _ in $(seq 1 30); do
    if curl -fsS -m 5 "${resolve[@]}" -o /dev/null "$HEALTH_URL"; then
      log "$app is healthy"
      return 0
    fi
    sleep 2
  done
  warn "$app: $HEALTH_URL did not succeed within 60 seconds"
  return 1
}
