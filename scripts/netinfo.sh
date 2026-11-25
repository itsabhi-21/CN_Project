#!/usr/bin/env bash
# Task A: print this Mac's network identity (save output as evidence)
source "$(dirname "$0")/lib.sh"
hr "$(hostname)  -  interface $IFACE"
echo "IPv4 address : $(ipconfig getifaddr "$IFACE")"
echo "Subnet mask  : $(ipconfig getoption "$IFACE" subnet_mask)"
echo "Prefix       : $(ifconfig "$IFACE" | awk '/inet /{print $4}')  (hex mask)"
echo "Gateway      : $(route -n get default 2>/dev/null | awk '/gateway/{print $2}')"
echo "Default if   : $(route -n get default 2>/dev/null | awk '/interface/{print $2}')"
echo "MAC address  : $(ifconfig "$IFACE" | awk '/ether/{print $2}')"
echo "DNS servers  : $(networksetup -getdnsservers "$NET_SERVICE" | tr '\n' ' ')"
