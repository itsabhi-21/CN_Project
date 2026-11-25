#!/usr/bin/env bash
# Point THIS Mac's resolver at the team DNS.
#   primary  -> Mac 1 only           (Phase 1)
#   both     -> Mac 1 then backup    (Phase 2 Ext A)
#   bogus    -> unreachable server   (failure demo 1)
#   reset    -> back to DHCP default
#   show     -> current settings
source "$(dirname "$0")/lib.sh"
flush(){ sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; }
case "${1:-show}" in
  primary) sudo networksetup -setdnsservers "$NET_SERVICE" "$MAC1_IP"; flush ;;
  both)    sudo networksetup -setdnsservers "$NET_SERVICE" "$MAC1_IP" "$BACKUP_DNS_IP"; flush ;;
  bogus)   sudo networksetup -setdnsservers "$NET_SERVICE" 10.255.255.1; flush ;;
  reset)   sudo networksetup -setdnsservers "$NET_SERVICE" Empty; flush ;;
  flush)   flush; echo "OS DNS cache flushed" ;;
esac
echo "DNS for $NET_SERVICE: $(networksetup -getdnsservers "$NET_SERVICE" | tr '\n' ' ')"
scutil --dns | awk '/resolver #1/{f=1} f&&/nameserver/{print "  in use:",$3} /resolver #2/{exit}'
