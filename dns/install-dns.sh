#!/usr/bin/env bash
# Run on Mac 1 (primary) - and on Mac 3 in Phase 2 (backup).
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
[[ -f "$ROOT/build/dns/dnsmasq.conf" ]] || { echo "run ./render.sh first"; exit 1; }
command -v dnsmasq >/dev/null || brew install dnsmasq
CONF="$BREW_PREFIX/etc/dnsmasq.conf"
[[ -f "$CONF" && ! -f "$CONF.orig" ]] && cp "$CONF" "$CONF.orig"
mkdir -p "$BREW_PREFIX/etc/dnsmasq.d"
cp "$ROOT/build/dns/dnsmasq.conf" "$CONF"
cp "$ROOT/build/dns/team.hosts"   "$BREW_PREFIX/etc/dnsmasq.d/team.hosts"
dnsmasq --test -C "$CONF"
sudo brew services restart dnsmasq
sleep 1
echo "--- self test ---"
dig +short @127.0.0.1 "app.$TEAM.test"
