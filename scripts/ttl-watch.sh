#!/usr/bin/env bash
# Ext B / Ext E: every 3 s print what the OS cache answers vs what the
# DNS server answers right now.  Ctrl+C to stop.
source "$(dirname "$0")/lib.sh"
NAME="${1:-app}.$TEAM.test"
printf "%-9s %-17s %-22s %s\n" TIME "OS-RESOLVER(cached)" "DNS-SERVER(dig) TTL" "X-Edge"
while true; do
  os=$(dscacheutil -q host -a name "$NAME" | awk '/ip_address/{print $2; exit}')
  srv=$(dig +noall +answer "$NAME" | awk '{print $5" ttl="$2; exit}')
  edge=$("${CURL[@]}" -D - -o /dev/null "$BASE/edge-health" 2>/dev/null \
         | awk -F': ' 'tolower($1)=="x-edge"{print $2}' | tr -d '\r')
  printf "%-9s %-17s %-22s %s\n" "$(date +%T)" "${os:-<none>}" "${srv:-<none>}" "${edge:--}"
  sleep 3
done
