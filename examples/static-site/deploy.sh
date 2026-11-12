#!/usr/bin/env bash
# Runs in CI (or locally) to publish a built site to /srv/www/<site> on a server
# set up with ops. Uploads a new release and switches to it atomically; earlier
# releases stay for `ops rollback <site>`.
# Usage: deploy.sh <ssh-destination> <site> [dist-dir]
# The SSH user must be DEPLOY_USER from the server's ops.conf.
set -euo pipefail

host=${1:?usage: deploy.sh <ssh-destination> <site> [dist-dir]}
site=${2:?usage: deploy.sh <ssh-destination> <site> [dist-dir]}
dist=${3:-dist}
base=/srv/www/$site
release=$(date -u +%Y%m%d%H%M%S)-${GITHUB_SHA:-local}
release=${release:0:22}
keep=5

ssh "$host" "mkdir -p '$base/releases/$release'"
rsync -az --delete --link-dest="$base/current/" "$dist/" "$host:$base/releases/$release/"

ssh "$host" bash -s -- "$base" "$release" "$keep" <<'REMOTE'
set -euo pipefail
cd "$1"
ln -sfn "releases/$2" current.next
mv -Tf current.next current
ls -1dt releases/* | tail -n +"$(($3 + 1))" | xargs -r rm -rf
REMOTE

echo "deployed $release to $host:$base"
