#!/usr/bin/env bash
# Task D / demo step 5 & 8: N requests, show which backend answered each
source "$(dirname "$0")/lib.sh"
N=${1:-10}; a=0; b=0; err=0
hr "$N requests to $BASE/api/status"
for i in $(seq 1 "$N"); do
  hdr=$("${CURL[@]}" -D - -o /dev/null "$BASE/api/status")
  code=$(echo "$hdr" | awk 'NR==1{print $2}')
  be=$(echo "$hdr" | awk -F': ' 'tolower($1)=="x-backend"{print $2}' | tr -d '\r')
  up=$(echo "$hdr" | awk -F': ' 'tolower($1)=="x-upstream"{print $2}' | tr -d '\r')
  printf "%2d  HTTP %-4s X-Backend: %-2s  upstream %s\n" "$i" "${code:-ERR}" "${be:--}" "${up:--}"
  case "$be" in A) a=$((a+1));; B) b=$((b+1));; *) err=$((err+1));; esac
done
echo "---  A=$a  B=$b  errors=$err"
