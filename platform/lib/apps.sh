# shellcheck shell=bash
# Starting, stopping and inspecting apps.

# Fails when the app's .env is missing or leaves a key from .env.example empty.
check_app_env() {
  local app=$1 example env key missing=()
  example=$(app_dir "$app")/.env.example
  env=$(app_data "$app")/.env
  [[ -f $example ]] || return 0
  if [[ ! -f $env ]]; then
    die "$app needs $env. Create it from $example (mode 600), then run ops up $app again"
  fi
  while IFS= read -r key; do
    grep -Eq "^${key}=.+" "$env" || missing+=("$key")
  done < <(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$example")
  ((${#missing[@]} == 0)) || die "$env has no value for: ${missing[*]}"
}

check_app_backup_targets() {
  local app=$1 target
  load_app_conf "$app"
  [[ -n $BACKUP_TARGETS ]] || die "$app: set BACKUP_TARGETS in app.conf (target names, or none)"
  [[ $BACKUP_TARGETS == none ]] && return 0
  [[ -f $OPS_ETC/backup.env ]] || die "$app backs up to '$BACKUP_TARGETS', but $OPS_ETC/backup.env does not exist yet (run ops init)"
  load_backup_env
  for target in $BACKUP_TARGETS; do
    target_defined "$target" || die "$app: backup target '$target' is not defined in $OPS_ETC/backup.env"
  done
}

cmd_up() {
  require_root
  load_ops_conf
  local app=${1:?usage: ops up <app>|edge}
  if [[ $app == edge ]]; then
    edge_up
    return
  fi
  require_app "$app"
  check_app_backup_targets "$app"
  lint_budget
  install -d -m 700 "$(app_data "$app")"

  if app_has_compose "$app"; then
    check_app_env "$app"
    ensure_network "$(app_network "$app")"
    app_compose "$app" pull --quiet
    check_app_arch "$app"
    app_compose "$app" up -d --remove-orphans
    edge_attach "$(app_network "$app")"
  fi
  if app_has_site "$app"; then
    cmd_reload_caddy
  fi
  log "$app is up"
}

cmd_down() {
  require_root
  load_ops_conf
  local app=${1:?usage: ops down <app>}
  require_app "$app"
  if app_has_compose "$app"; then
    app_compose "$app" down
    edge_detach "$(app_network "$app")"
    docker network rm "$(app_network "$app")" >/dev/null 2>&1 || true
  fi
  log "$app is down. Its route stays loaded until the app directory is removed and Caddy is reloaded"
}

cmd_logs() {
  local app=${1:?usage: ops logs <app>|edge}
  shift
  if [[ $app == edge ]]; then
    edge_compose logs --tail 100 "$@"
    return
  fi
  require_app "$app"
  app_compose "$app" logs --tail 100 "$@"
}

# Warns when a pulled image was built for another CPU architecture, which
# Docker would otherwise run slowly under emulation or not at all.
check_app_arch() {
  local app=$1 image arch
  while IFS= read -r image; do
    [[ -n $image ]] || continue
    arch=$(docker image inspect -f '{{.Architecture}}' "$image" 2>/dev/null || true)
    if [[ -n $arch && $arch != "$OPS_ARCH" ]]; then
      die "$app: image $image is $arch, but this server is $OPS_ARCH"
    fi
  done < <(app_compose "$app" config --images)
}

cmd_status() {
  load_ops_conf
  local app status
  echo "host: $OPS_HOST ($OPS_ARCH)  platform: $(cat "$OPS_ROOT/VERSION")  revision: $(cat "$OPS_ROOT/.revision" 2>/dev/null || echo unknown)"
  echo
  printf '%-16s %-10s %-40s %s\n' APP CONTAINERS "LAST BACKUP" TARGETS
  for app in $(list_apps); do
    load_app_conf "$app"
    if app_has_compose "$app"; then
      status="$(app_compose "$app" ps --status running -q 2>/dev/null | wc -l)/$(app_compose "$app" config --services 2>/dev/null | wc -l)"
    else
      status="static"
    fi
    printf '%-16s %-10s %-40s %s\n' "$app" "$status" \
      "$(cat "$OPS_STATE/backup/$app.status" 2>/dev/null || echo -)" "${BACKUP_TARGETS:-?}"
  done
  echo
  lint_budget report
  if [[ ${1:-} == --usage ]]; then
    echo
    backup_usage
  fi
}

# Creates apps/<name> from the template. Run it in the instance repository on
# your own machine, not on the server.
cmd_new() {
  local app=${1:?usage: ops new <app>}
  [[ $app =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid app name: $app"
  [[ ! -e $(app_dir "$app") ]] || die "$(app_dir "$app") already exists"
  cp -r "$OPS_ROOT/platform/templates/app" "$(app_dir "$app")"
  grep -rl '__APP__' "$(app_dir "$app")" | xargs sed -i "s/__APP__/$app/g"
  echo "Created $(app_dir "$app"). Fill in every file, then commit and sync."
}

# Lists the releases of a static site, or switches back to one of them.
cmd_rollback() {
  require_root
  local site=${1:?usage: ops rollback <site> [release]} dir
  dir=$OPS_WWW_ROOT/$site
  [[ -d $dir/releases ]] || die "$dir/releases does not exist"
  cd "$dir" || return
  if [[ $# -lt 2 ]]; then
    echo "current -> $(readlink current)"
    ls -1t releases
    return
  fi
  [[ -d releases/$2 ]] || die "no release $2"
  ln -sfn "releases/$2" current.next
  mv -Tf current.next current
  echo "current -> releases/$2"
}
