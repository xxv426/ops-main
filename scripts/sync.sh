#!/usr/bin/env bash
# Copies the committed state of this repository to a server's /opt/ops,
# deleting files that were removed from Git. Runs on your own machine.
# Usage: scripts/sync.sh [--force] [--no-lint] <ssh-host>
#
# Before anything on the server changes, it checks there that:
#   - /opt/ops belongs to the same OPS_HOST as this repository, so one server's
#     instance is never synced over another's (--force replaces it anyway);
#   - `ops lint` passes on the new files, so a broken route never reaches the
#     directory the edge Caddy reads (--no-lint skips this).
# It then records the commit in /opt/ops/.revision, which `ops status` shows.
#
# Uses OPS_SSH if set. On Windows it prefers the system OpenSSH, which can use
# keys held by a password manager's SSH agent; Git Bash's own ssh cannot.
set -euo pipefail

usage="usage: scripts/sync.sh [--force] [--no-lint] <ssh-host>"
force=0
lint=1
host=""
while (($#)); do
  case $1 in
    --force) force=1 ;;
    --no-lint) lint=0 ;;
    -*)
      echo "$usage" >&2
      exit 1
      ;;
    *) host=$1 ;;
  esac
  shift
done
[[ -n $host ]] || {
  echo "$usage" >&2
  exit 1
}
dest=/opt/ops
cd "$(git rev-parse --show-toplevel)"

if [[ -n ${OPS_SSH:-} ]]; then
  ssh_cmd=$OPS_SSH
elif [[ -x /c/Windows/System32/OpenSSH/ssh.exe ]]; then
  ssh_cmd=/c/Windows/System32/OpenSSH/ssh.exe
else
  ssh_cmd=ssh
fi

if [[ -n $(git status --porcelain) ]]; then
  echo "warning: uncommitted changes are not synced; only HEAD ($(git rev-parse --short HEAD)) is" >&2
fi
[[ -f ops.conf ]] || echo "warning: no ops.conf in this repository; ops will not run on the server" >&2

# Single-quoted for the remote shell, so it contains no single quotes. DEST,
# REV, FORCE and LINT are filled in below.
remote='set -euo pipefail
sudo=""
[ "$(id -u)" -eq 0 ] || sudo="sudo -n"
tmp=$(mktemp -d)
trap "rm -rf $tmp" EXIT
tar -x -C "$tmp"
echo "REV synced $(date -u +%FT%TZ)" >"$tmp/.revision"

host_of() { sed -n "s/^OPS_HOST=\([^ #]*\).*/\1/p" | tail -n 1 | tr -d "\""; }
new_host=""
[ ! -f "$tmp/ops.conf" ] || new_host=$(host_of <"$tmp/ops.conf")
old_host=$($sudo cat DEST/ops.conf 2>/dev/null | host_of || true)
if [ -n "$old_host" ] && [ "$old_host" != "$new_host" ] && [ FORCE != 1 ]; then
  echo "error: DEST on this server is the instance OPS_HOST=$old_host, but this repository is OPS_HOST=${new_host:-<none>}. Nothing was changed. Check the ssh host, or pass --force to replace it." >&2
  exit 1
fi

if [ LINT = 1 ] && [ -n "$new_host" ]; then
  if command -v docker >/dev/null && command -v jq >/dev/null; then
    if ! $sudo env OPS_ROOT="$tmp" bash "$tmp/platform/bin/ops" lint </dev/null; then
      echo "error: ops lint failed on the new files. Nothing was changed. Fix it, or pass --no-lint." >&2
      exit 1
    fi
  else
    echo "note: lint skipped; docker and jq are not installed yet (bootstrap.sh installs them)" >&2
  fi
fi

$sudo mkdir -p DEST
if command -v rsync >/dev/null; then
  $sudo rsync -a --delete --chown=root:root "$tmp/" DEST/
else
  $sudo rm -rf DEST.old
  $sudo mv DEST DEST.old
  $sudo mv "$tmp" DEST
  $sudo chown -R root:root DEST
  $sudo rm -rf DEST.old
fi'
remote=${remote//DEST/$dest}
remote=${remote//REV/$(git rev-parse --short HEAD)}
remote=${remote//FORCE/$force}
remote=${remote//LINT/$lint}

git archive --format=tar HEAD | "$ssh_cmd" "$host" "bash -c '$remote'"
echo "synced $(git rev-parse --short HEAD) to $host:$dest"
