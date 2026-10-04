#!/usr/bin/env bash
# Renders every *.tmpl into build/ with your IPs from config.env
set -euo pipefail
cd "$(dirname "$0")"
source ./config.env
rm -rf build && mkdir -p build
find dns nginx firewall -name '*.tmpl' | while read -r f; do
  out="build/${f%.tmpl}"
  mkdir -p "$(dirname "$out")"
  sed -e "s|__TEAM__|$TEAM|g" \
      -e "s|__MAC1_IP__|$MAC1_IP|g" -e "s|__MAC2_IP__|$MAC2_IP|g" \
      -e "s|__MAC3_IP__|$MAC3_IP|g" -e "s|__MAC4_IP__|$MAC4_IP|g" \
      -e "s|__BACKUP_DNS_IP__|$BACKUP_DNS_IP|g" \
      -e "s|__STANDBY_EDGE_IP__|$STANDBY_EDGE_IP|g" \
      -e "s|__PORT_A__|$PORT_A|g" -e "s|__PORT_B__|$PORT_B|g" \
      -e "s|__HTTPS_PORT__|$HTTPS_PORT|g" -e "s|__HTTP_PORT__|$HTTP_PORT|g" \
      -e "s|__UPSTREAM_DNS__|$UPSTREAM_DNS|g" -e "s|__DNS_TTL__|$DNS_TTL|g" \
      -e "s|__BREW_PREFIX__|$BREW_PREFIX|g" \
      "$f" > "$out"
  echo "rendered $out"
done
