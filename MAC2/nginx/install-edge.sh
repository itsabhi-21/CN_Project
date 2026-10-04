#!/usr/bin/env bash
# usage: nginx/install-edge.sh phase1|phase2
# Run on Mac 2 (and on Mac 3 for the standby edge in Ext E).
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
PHASE="${1:-phase1}"
SRC="$ROOT/build/nginx/edge-$PHASE.conf"
[[ -f "$SRC" ]] || { echo "run ./render.sh first"; exit 1; }
[[ -f "$ROOT/tls/out/server.crt" ]] || { echo "run tls/make-certs.sh first (or copy tls/out/ from Mac 2)"; exit 1; }
command -v nginx >/dev/null || brew install nginx
mkdir -p "$BREW_PREFIX/etc/nginx/servers" "$BREW_PREFIX/etc/nginx/certs"
cp "$ROOT/tls/out/server.crt" "$ROOT/tls/out/server.key" "$BREW_PREFIX/etc/nginx/certs/"
chmod 600 "$BREW_PREFIX/etc/nginx/certs/server.key"
cp "$SRC" "$BREW_PREFIX/etc/nginx/servers/team.conf"
sudo nginx -t
if pgrep -x nginx >/dev/null; then sudo nginx -s reload; else sudo nginx; fi
echo "nginx running with $PHASE config"
