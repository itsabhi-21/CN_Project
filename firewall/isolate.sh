#!/usr/bin/env bash
# usage: firewall/isolate.sh apply|status|rollback   (run on Mac 3 and Mac 4)
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
ANCHOR="com.apple/team-isolation"
RULES="$ROOT/build/firewall/backend-pf.conf"
STATE="$ROOT/firewall/rollback"; mkdir -p "$STATE"
case "${1:-status}" in
  apply)
    sudo cp /etc/pf.conf "$STATE/pf.conf.backup"            # rollback copy
    sudo pfctl -s rules > "$STATE/main-rules-before.txt" 2>/dev/null || true
    sudo pfctl -s info  > "$STATE/pf-info-before.txt"    2>/dev/null || true
    sudo pfctl -nf "$RULES" -a "$ANCHOR"                     # syntax check
    sudo pfctl -a "$ANCHOR" -f "$RULES"
    sudo pfctl -E 2>&1 | awk '/Token/{print $NF}' > "$STATE/pf.token"
    echo "applied. active anchor rules:"; sudo pfctl -a "$ANCHOR" -s rules ;;
  status)
    sudo pfctl -s info | head -2; echo "anchor rules:"
    sudo pfctl -a "$ANCHOR" -s rules 2>/dev/null || echo "(none)" ;;
  rollback)
    sudo pfctl -a "$ANCHOR" -F all
    [[ -s "$STATE/pf.token" ]] && sudo pfctl -X "$(cat "$STATE/pf.token")" || true
    rm -f "$STATE/pf.token"
    echo "rolled back. /etc/pf.conf was never modified (backup in $STATE)." ;;
esac
