#!/usr/bin/env bash
# Ext F: systematic bottom-up-the-request diagnosis.
#   DNS  ->  IP reachability  ->  TCP port  ->  TLS  ->  HTTP/app
# usage: scripts/diagnose.sh [name] [port]
source "$(dirname "$0")/lib.sh"
NAME="${1:-app.$TEAM.test}"; PORT="${2:-$HTTPS_PORT}"
ok(){ printf "  \033[32mPASS\033[0m %s\n" "$*"; }
bad(){ printf "  \033[31mFAIL\033[0m %s\n" "$*"; }

hr "1. DNS  (Application layer, UDP/53)"
echo "  resolvers this Mac uses: $(scutil --dns | awk '/nameserver/{print $3}' | sort -u | tr '\n' ' ')"
for s in "$MAC1_IP" "$BACKUP_DNS_IP"; do
  r=$(dig +short +time=2 +tries=1 @"$s" "$NAME" 2>/dev/null | tail -1)
  [[ "$r" =~ ^[0-9.]+$ ]] && ok "@$s says $NAME -> $r" || bad "@$s no answer (${r:-timeout})"
done
IP=$(dscacheutil -q host -a name "$NAME" | awk '/ip_address/{print $2; exit}')
[[ -n "$IP" ]] && ok "OS resolver (what apps use) -> $IP" || { bad "OS resolver cannot resolve $NAME"; exit 1; }
[[ "$IP" == "$MAC2_IP" || "$IP" == "$STANDBY_EDGE_IP" ]] && ok "IP is a known edge" \
  || bad "IP $IP is NOT an edge (Mac2=$MAC2_IP) - wrong record?"

hr "2. IP reachability  (Network layer, ICMP)"
ping -c 2 -t 3 "$IP" >/dev/null 2>&1 && ok "ping $IP" || bad "ping $IP (host down / different LAN / ICMP blocked)"

hr "3. TCP  (Transport layer, port $PORT)"
if nc -z -G 3 "$IP" "$PORT" 2>/dev/null; then ok "TCP handshake to $IP:$PORT"
else bad "TCP $IP:$PORT  (refused = nothing listening / RST; timeout = filtered)"; fi

hr "4. TLS  (certificate + handshake)"
TLS=$(openssl s_client -connect "$IP:$PORT" -servername "$NAME" -CAfile "$CA" </dev/null 2>/dev/null)
echo "$TLS" | grep -E '^subject=|^issuer=|Protocol *:|Verify return code' | sed 's/^/  /'
echo "$TLS" | grep -q 'Verify return code: 0' && ok "certificate valid for chain" || bad "TLS handshake / verification failed"
echo "$TLS" | openssl x509 -noout -checkend 0 >/dev/null 2>&1 && ok "certificate not expired" || bad "certificate expired / missing"
echo "$TLS" | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -q "$NAME" && ok "SAN contains $NAME" || bad "SAN does not contain $NAME"

hr "5. HTTP / application"
P=""; [[ "$PORT" != 443 ]] && P=":$PORT"
R=$("${CURL[@]}" --cacert "$CA" -D - "https://$NAME$P/api/status")
echo "$R" | grep -iE '^HTTP/|^x-backend|^x-edge|^x-upstream' | sed 's/^/  /'
code=$(echo "$R" | awk 'NR==1{print $2}')
case "$code" in
  200) ok "application healthy" ;;
  502|504) bad "$code from edge: edge is fine, BACKENDS unreachable (down / wrong upstream IP:port / pf / bound to 127.0.0.1)" ;;
  "") bad "no HTTP response" ;;
  *) bad "HTTP $code" ;;
esac
