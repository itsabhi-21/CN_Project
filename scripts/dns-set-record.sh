#!/usr/bin/env bash
# Change a project record live. Run on EVERY DNS server (Mac 1 + backup).
#   scripts/dns-set-record.sh app 192.168.1.13
#   scripts/dns-set-record.sh app reset        # back to Mac 2
set -euo pipefail
source "$(dirname "$0")/lib.sh"
NAME="$1.$TEAM.test"; IP="$2"
[[ "$IP" == reset ]] && IP="$MAC2_IP"
F="$BREW_PREFIX/etc/dnsmasq.d/team.hosts"
NAME_RE="${NAME//./\\.}"
sudo sed -i '' -E "s|^[0-9.]+([[:space:]]+${NAME_RE})\$|${IP}\1|" "$F"
sudo pkill -HUP dnsmasq      # re-read hosts file + clear dnsmasq cache
echo "$(date +%T)  $NAME -> $IP"
grep -E "[[:space:]]${NAME_RE}\$" "$F"
