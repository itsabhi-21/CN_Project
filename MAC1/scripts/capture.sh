#!/usr/bin/env bash
# Task G: capture DNS + TCP + TLS for ONE fresh request, save .pcap.
# Run on Mac 4 (a client that is NOT the DNS server - on Mac 1 the DNS
# query would go over loopback lo0 instead of the LAN).
source "$(dirname "$0")/lib.sh"
TLSMAX="${1:-1.2}"   # 1.2 = Certificate visible in clear; 1.3 = encrypted
OUT="$ROOT/evidence/captures/flow-tls${TLSMAX}-$(date +%H%M%S).pcap"
FILTER="udp port 53 or (host $MAC2_IP and tcp port $HTTPS_PORT)"

sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder   # force a real DNS query
sudo tcpdump -i "$IFACE" -s 0 -w "$OUT" "$FILTER" 2>/dev/null &
sleep 2
hr "request (TLS max $TLSMAX)"
"${CURL[@]}" -v --tls-max "$TLSMAX" "$BASE/api/status" 2>&1 \
   | grep -E '^\* (Connected|.*TLS|.*SSL|.*ALPN|.*subject|.*issuer|.*verify|.*certificate)|^[<>] '
sleep 2
sudo pkill -INT -f "tcpdump -i $IFACE -s 0 -w $OUT"
sleep 1
echo; echo "saved: $OUT"
echo "Open in Wireshark. Useful display filters:"
echo "  dns                              DNS query + response"
echo "  tcp.flags.syn==1                 SYN / SYN-ACK"
echo "  tls.handshake                    ClientHello/ServerHello/Certificate"
echo "  tls.handshake.type==11           Certificate (only visible with TLS 1.2)"
echo "  tls.record.content_type==23      encrypted Application Data"
echo "  Statistics > Flow Graph          whole conversation as a ladder diagram"
