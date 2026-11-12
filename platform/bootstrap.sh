#!/usr/bin/env bash
# Prepares a server for ops. Safe to run again.
# Usage: sudo bootstrap.sh [--web] [--deploy-key '<ssh public key>']
#   --web         open 80/443 in the host firewall (servers that serve sites)
#   --deploy-key  key that CI uses to publish static sites as DEPLOY_USER
set -euo pipefail

OPS_ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
# shellcheck source=lib/common.sh
source "$OPS_ROOT/platform/lib/common.sh"

# Pinned restic release and the checksums from its SHA256SUMS file.
RESTIC_VERSION=0.19.1
declare -A RESTIC_SHA256=(
  [amd64]=f415415624dcc452f2a02b8c33641791a8c6d6d3b65bbb3543fcf9a25151585c
  [arm64]=a5f64aaab53d51e311fa3829124c5b703f2d14cf187d8640b6be3b2b49376465
)

web=0
deploy_key=""
while (($#)); do
  case $1 in
    --web) web=1; shift ;;
    --deploy-key) deploy_key=${2:?}; shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done

require_root
load_ops_conf

case $(uname -m) in
  x86_64) machine_arch=amd64 ;;
  aarch64) machine_arch=arm64 ;;
  *) die "unsupported CPU: $(uname -m)" ;;
esac
[[ $machine_arch == "$OPS_ARCH" ]] || die "ops.conf says OPS_ARCH=$OPS_ARCH, but this server is $machine_arch"

# shellcheck disable=SC1091
source /etc/os-release
[[ $ID == ubuntu || $ID == debian ]] || die "only Ubuntu and Debian are supported"

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q ca-certificates curl jq rsync sqlite3 bzip2 openssl
if ! command -v docker >/dev/null; then
  if [[ $ID == ubuntu ]]; then
    apt-get install -y -q docker.io docker-compose-v2
  else
    die "install Docker from https://docs.docker.com/engine/install/debian/ first, then run this again"
  fi
fi
docker compose version >/dev/null || die "docker compose v2 is required"
systemctl enable --now docker

# Rotate container logs everywhere instead of in every compose file. Applies to
# containers created after Docker restarts.
if [[ ! -f /etc/docker/daemon.json ]]; then
  install -m 644 "$OPS_ROOT/platform/docker/daemon.json" /etc/docker/daemon.json
  if [[ -z $(docker ps -q) ]]; then
    systemctl restart docker
  else
    warn "wrote /etc/docker/daemon.json; restart Docker at a quiet time (systemctl restart docker) to apply it"
  fi
elif ! grep -q '"log-opts"' /etc/docker/daemon.json; then
  warn "/etc/docker/daemon.json has no log-opts; merge in $OPS_ROOT/platform/docker/daemon.json by hand"
fi

# restic from the official release, not the distribution's (often years old).
if [[ $(restic version 2>/dev/null | awk '{print $2}') != "$RESTIC_VERSION" ]]; then
  tmp=$(mktemp -d)
  file=restic_${RESTIC_VERSION}_linux_${OPS_ARCH}.bz2
  curl -fsSL -o "$tmp/$file" "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/$file"
  echo "${RESTIC_SHA256[$OPS_ARCH]}  $tmp/$file" | sha256sum -c --quiet
  bunzip2 "$tmp/$file"
  install -m 755 "$tmp/${file%.bz2}" /usr/local/bin/restic
  rm -rf "$tmp"
fi
log "restic $(/usr/local/bin/restic version | awk '{print $2}')"

# BBR copes better than the default with loss on long-distance routes.
cat >/etc/sysctl.d/90-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl --system >/dev/null

# Oracle's Ubuntu images end the INPUT chain with a REJECT rule, so opening a
# port in the cloud firewall is not enough there. Other hosts are left alone.
if ((web)); then
  reject_line=$(iptables -L INPUT --line-numbers 2>/dev/null | awk '/REJECT/ { print $1; exit }' || true)
  if [[ -n $reject_line ]]; then
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    apt-get install -y -q iptables-persistent
    for rule in "tcp 80" "tcp 443" "udp 443"; do
      read -r proto port <<<"$rule"
      iptables -C INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null ||
        iptables -I INPUT "$reject_line" -p "$proto" --dport "$port" -j ACCEPT
    done
    netfilter-persistent save
  fi
  log "also allow TCP 80, TCP 443 and UDP 443 in the cloud firewall"
fi

install -d -m 700 "$OPS_ETC" "$OPS_DATA_ROOT" "$OPS_STAGE_ROOT"
install -d -m 755 "$OPS_STATE" "$OPS_LOG_DIR"
ln -sfn "$OPS_ROOT/platform/bin/ops" /usr/local/bin/ops

if [[ -n $DEPLOY_USER ]]; then
  id "$DEPLOY_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$DEPLOY_USER"
  install -d -m 755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$OPS_WWW_ROOT"
  if [[ -n $deploy_key ]]; then
    home=$(getent passwd "$DEPLOY_USER" | cut -d: -f6)
    install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$home/.ssh"
    touch "$home/.ssh/authorized_keys"
    grep -qxF "$deploy_key" "$home/.ssh/authorized_keys" || echo "$deploy_key" >>"$home/.ssh/authorized_keys"
    chown "$DEPLOY_USER:$DEPLOY_USER" "$home/.ssh/authorized_keys"
    chmod 600 "$home/.ssh/authorized_keys"
  fi
fi

log "bootstrap finished. Next: ops init"
