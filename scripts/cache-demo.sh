#!/usr/bin/env bash
# Task F / demo step 7: full response vs conditional (304) request
source "$(dirname "$0")/lib.sh"
URL="$BASE/api/catalog"
show(){ grep -iE '^HTTP/|^cache-control|^etag|^last-modified|^content-length|^x-backend'; }

hr "1) HEAD - inspect cache headers (curl -I)"
"${CURL[@]}" -I "$URL" | show

hr "2) Full GET - server sends the whole body (200)"
"${CURL[@]}" -D - -o /dev/null -w "body bytes: %{size_download}\n" "$URL" | show

ETAG=$("${CURL[@]}" -D - -o /dev/null "$URL" | awk -F': ' 'tolower($1)=="etag"{print $2}' | tr -d '\r')
hr "3) Conditional GET with If-None-Match: $ETAG  -> expect 304"
"${CURL[@]}" -D - -o /dev/null -w "body bytes: %{size_download}\n" \
     -H "If-None-Match: $ETAG" "$URL" | show

hr "4) Conditional GET with a stale ETag -> expect full 200"
"${CURL[@]}" -D - -o /dev/null -w "body bytes: %{size_download}\n" \
     -H 'If-None-Match: "old-version"' "$URL" | show

echo; echo "Fresh cache hit: open $URL in a browser, DevTools > Network,"
echo "reload within 60 s (click the link, don't hard-refresh): Size column shows '(disk cache)' / '(memory cache)'."
