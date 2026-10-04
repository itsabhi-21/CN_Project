#!/usr/bin/env bash
# Task A: reachability to every team Mac
source "$(dirname "$0")/lib.sh"
for pair in "Mac1:$MAC1_IP" "Mac2:$MAC2_IP" "Mac3:$MAC3_IP" "Mac4:$MAC4_IP"; do
  n=${pair%%:*}; ip=${pair#*:}
  if out=$(ping -c 3 -t 5 "$ip" 2>&1); then
    printf "%-5s %-15s OK   %s\n" "$n" "$ip" "$(echo "$out" | tail -1)"
  else
    printf "%-5s %-15s FAIL\n" "$n" "$ip"
  fi
done
