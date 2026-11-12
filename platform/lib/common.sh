# shellcheck shell=bash
# Variables here are used by the other files in lib/.
# shellcheck disable=SC2034
# Shared paths and helpers for the ops command. Sourced, never executed.

OPS_ROOT=${OPS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
OPS_CONF=${OPS_CONF:-$OPS_ROOT/ops.conf}
OPS_APPS_DIR=${OPS_APPS_DIR:-$OPS_ROOT/apps}
OPS_ETC=${OPS_ETC:-/etc/ops}
OPS_STATE=${OPS_STATE:-/var/lib/ops}
OPS_LOG_DIR=${OPS_LOG_DIR:-/var/log/ops}
OPS_STAGE_ROOT=${OPS_STAGE_ROOT:-/var/backups/ops}
OPS_DATA_ROOT=${OPS_DATA_ROOT:-/srv/apps}
OPS_WWW_ROOT=${OPS_WWW_ROOT:-/srv/www}
OPS_EDGE_DIR=$OPS_ROOT/platform/edge

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ $EUID -eq 0 ]] || die "run as root"
}

# This machine's CPU architecture, named the way Docker and restic name it.
machine_arch() {
  case $(uname -m) in
    x86_64) echo amd64 ;;
    aarch64 | arm64) echo arm64 ;;
    *) uname -m ;;
  esac
}

load_ops_conf() {
  [[ -f $OPS_CONF ]] || die "missing $OPS_CONF (copy ops.conf.example and fill it in)"
  # shellcheck disable=SC1090
  source "$OPS_CONF"
  : "${OPS_HOST:?OPS_HOST is not set in ops.conf}"
  # Detected, not configured: everything that uses it runs on the server.
  OPS_ARCH=$(machine_arch)
  : "${RESOURCE_BUDGET_CPUS:?RESOURCE_BUDGET_CPUS is not set in ops.conf}"
  : "${RESOURCE_BUDGET_MEM:?RESOURCE_BUDGET_MEM is not set in ops.conf}"
  BACKUP_TIME=${BACKUP_TIME:-"30 19 * * *"}
  CHECK_TIME=${CHECK_TIME:-"0 21 * * 0"}
  DEPLOY_USER=${DEPLOY_USER:-}
}

# Apps are the directories under apps/ that contain an app.conf.
list_apps() {
  local dir
  for dir in "$OPS_APPS_DIR"/*/; do
    [[ -f $dir/app.conf ]] && basename "$dir"
  done
  return 0
}

app_dir() { printf '%s/%s' "$OPS_APPS_DIR" "$1"; }
app_data() { printf '%s/%s' "$OPS_DATA_ROOT" "$1"; }
app_has_compose() { [[ -f $(app_dir "$1")/compose.yaml ]]; }
app_has_site() { [[ -f $(app_dir "$1")/site.caddy ]]; }

require_app() {
  [[ $1 =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid app name: $1"
  [[ -f $(app_dir "$1")/app.conf ]] || die "no such app: $1 (expected $(app_dir "$1")/app.conf)"
}

# Loads app.conf into APP_* and BACKUP_* variables, clearing values left over
# from a previous app.
load_app_conf() {
  APP_DOMAINS=""
  HEALTH_URL=""
  BACKUP_TARGETS=""
  BACKUP_KEEP=""
  BACKUP_EXCLUDE=""
  # shellcheck disable=SC1090
  source "$(app_dir "$1")/app.conf"
}

# docker compose for one app. The app's .env is passed for both interpolation
# and env_file, so compose files can use either.
app_compose() {
  local app=$1
  shift
  local args=(--project-directory "$(app_dir "$app")" -f "$(app_dir "$app")/compose.yaml")
  if [[ -f $(app_data "$app")/.env ]]; then
    args+=(--env-file "$(app_data "$app")/.env")
  elif [[ -f $(app_dir "$app")/.env.example ]]; then
    args+=(--env-file "$(app_dir "$app")/.env.example")
  fi
  docker compose "${args[@]}" "$@"
}

# Converts sizes such as 512m, 12g or 268435456 to bytes.
to_bytes() {
  local value=${1,,}
  local number=${value%[bkmg]}
  case $value in
    *g) echo $((number * 1024 * 1024 * 1024)) ;;
    *m) echo $((number * 1024 * 1024)) ;;
    *k) echo $((number * 1024)) ;;
    *) echo "$number" ;;
  esac
}

human_bytes() {
  awk -v b="$1" 'BEGIN { split("B KiB MiB GiB TiB", u); i = 1; while (b >= 1024 && i < 5) { b /= 1024; i++ } printf "%.1f %s", b, u[i] }'
}
