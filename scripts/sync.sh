#!/usr/bin/env bash
# Copies the committed state of this repository to a server's /opt/ops,
# deleting files that were removed from Git. Runs on your own machine.
# Usage: scripts/sync.sh <ssh-host>
#
# Uses OPS_SSH if set. On Windows it prefers the system OpenSSH, which can use
# keys held by a password manager's SSH agent; Git Bash's own ssh cannot.
set -euo pipefail

host=${1:?usage: scripts/sync.sh <ssh-host>}
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

# Single-quoted for the remote shell, so it contains no single quotes.
remote='set -euo pipefail
sudo=""
[ "$(id -u)" -eq 0 ] || sudo="sudo -n"
tmp=$(mktemp -d)
trap "rm -rf $tmp" EXIT
tar -x -C "$tmp"
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

git archive --format=tar HEAD | "$ssh_cmd" "$host" "bash -c '$remote'"
echo "synced $(git rev-parse --short HEAD) to $host:$dest"
