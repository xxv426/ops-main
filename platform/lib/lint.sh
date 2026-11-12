# shellcheck shell=bash
# Static checks for an instance repository. Needs docker but not root, so CI
# and your own machine can run it before anything reaches a server.

lint_errors=0
lint_fail() {
  printf 'lint: %s\n' "$*" >&2
  lint_errors=$((lint_errors + 1))
}

# Sums the CPU and memory limits of every service, including the edge, and
# compares them with the budget in ops.conf. With "report" it only prints.
# shellcheck disable=SC2120
lint_budget() {
  local mode=${1:-check} cpus=0 mem=0 app json budget_mem service_count limited_count
  for app in $(list_apps); do
    app_has_compose "$app" || continue
    json=$(app_compose "$app" config --format json 2>/dev/null) || continue
    service_count=$(jq '.services | length' <<<"$json")
    limited_count=$(jq '[.services[] | select(.cpus != null and .mem_limit != null)] | length' <<<"$json")
    if [[ $mode == check && $service_count != "$limited_count" ]]; then
      die "$app: every service needs cpus and mem_limit"
    fi
    cpus=$(jq -r --arg c "$cpus" '[.services[].cpus // 0 | tonumber] | add + ($c | tonumber)' <<<"$json")
    mem=$(jq -r --arg m "$mem" '[.services[].mem_limit // 0 | tonumber] | add + ($m | tonumber)' <<<"$json")
  done
  if any_site; then
    json=$(OPS_WWW_ROOT=$OPS_WWW_ROOT docker compose --project-directory "$OPS_EDGE_DIR" -f "$OPS_EDGE_DIR/compose.yaml" config --format json)
    cpus=$(jq -r --arg c "$cpus" '[.services[].cpus // 0 | tonumber] | add + ($c | tonumber)' <<<"$json")
    mem=$(jq -r --arg m "$mem" '[.services[].mem_limit // 0 | tonumber] | add + ($m | tonumber)' <<<"$json")
  fi
  budget_mem=$(to_bytes "$RESOURCE_BUDGET_MEM")
  echo "limits: $cpus CPU, $(human_bytes "$mem")  budget: $RESOURCE_BUDGET_CPUS CPU, $(human_bytes "$budget_mem")"
  [[ $mode == report ]] && return 0
  if awk -v a="$cpus" -v b="$RESOURCE_BUDGET_CPUS" 'BEGIN { exit !(a > b) }' || ((mem > budget_mem)); then
    die "resource limits exceed the budget in ops.conf"
  fi
}

lint_app() {
  local app=$1 dir
  dir=$(app_dir "$app")
  [[ $app =~ ^[a-z0-9][a-z0-9-]*$ ]] || lint_fail "$app: app names use lowercase letters, digits and hyphens"
  [[ -f $dir/README.md ]] || lint_fail "$app: missing README.md"
  load_app_conf "$app"
  if [[ -z $BACKUP_TARGETS ]]; then
    lint_fail "$app: BACKUP_TARGETS must be set (target names, or none)"
  elif [[ $BACKUP_TARGETS != none ]]; then
    [[ -n $BACKUP_KEEP ]] || lint_fail "$app: BACKUP_KEEP must be set when backups are on"
    [[ -f $dir/backup-hook.sh ]] || lint_fail "$app: missing backup-hook.sh"
    [[ -f $dir/restore-hook.sh ]] || lint_fail "$app: missing restore-hook.sh"
  fi
  if app_has_compose "$app"; then
    local json
    if ! json=$(app_compose "$app" config --format json 2>&1); then
      lint_fail "$app: compose.yaml is invalid: $json"
      return
    fi
    [[ $(jq -r '.name' <<<"$json") == "$app" ]] || lint_fail "$app: compose.yaml must set name: $app"
    if app_has_site "$app" && ! jq -e --arg n "$(app_network "$app")" '.networks | to_entries | any(.value.name == $n and .value.external == true)' <<<"$json" >/dev/null; then
      lint_fail "$app: has site.caddy, so compose.yaml must join the external network $(app_network "$app")"
    fi
    if jq -e '[.services[].ports[]? | select((.host_ip // "") == "" or .host_ip == "0.0.0.0")] | length > 0' <<<"$json" >/dev/null; then
      lint_fail "$app: publishes a port on all interfaces; bind it to 127.0.0.1 or a private IP, and route public traffic through site.caddy"
    fi
    if jq -e '[.services[] | .image // "built:local" | select(endswith(":latest") or (contains(":") | not))] | length > 0' <<<"$json" >/dev/null; then
      lint_fail "$app: pin every image to a version tag"
    fi
  fi
}

cmd_lint() {
  load_ops_conf
  local app apps
  mapfile -t apps < <(list_apps)
  echo "linting ${#apps[@]} app(s) in $OPS_APPS_DIR"
  for app in "${apps[@]}"; do
    lint_app "$app"
  done

  if ((${#apps[@]})); then
    lint_budget || lint_errors=$((lint_errors + 1))
  fi

  if any_site; then
    local err
    err=$(mktemp)
    docker run --rm \
      -v "$OPS_EDGE_DIR/caddy:/etc/caddy:ro" \
      -v "$OPS_APPS_DIR:/etc/ops-apps:ro" \
      "$(edge_image)" caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>"$err" ||
      lint_fail "Caddy configuration is invalid: $(tail -n 3 "$err")"
    rm -f "$err"
  fi

  if command -v shellcheck >/dev/null; then
    local scripts=()
    mapfile -t scripts < <(find "$OPS_ROOT/platform" "$OPS_ROOT/scripts" "$OPS_APPS_DIR" -name '*.sh' -type f 2>/dev/null)
    scripts+=("$OPS_ROOT/platform/bin/ops")
    shellcheck -x -S warning "${scripts[@]}" || lint_fail "shellcheck reported problems"
  else
    warn "shellcheck is not installed; skipped"
  fi

  ((lint_errors == 0)) || die "$lint_errors problem(s) found"
  echo "lint passed"
}

edge_image() {
  sed -n 's/^ *image: *//p' "$OPS_EDGE_DIR/compose.yaml" | head -n 1
}
