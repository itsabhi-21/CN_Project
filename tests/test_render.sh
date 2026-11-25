#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./render.sh

if [[ ! -d build ]]; then
  echo "FAIL: build/ directory was not created" >&2
  exit 1
fi

# Verify no unrendered __TOKEN__ placeholders remain in build/
if grep -rn '__[A-Z0-9_]*__' build/; then
  echo "FAIL: unrendered template placeholders found in build/" >&2
  exit 1
fi

# Verify expected rendered files exist
for expected in \
  build/dns/dnsmasq.conf \
  build/dns/team.hosts \
  build/nginx/edge-phase1.conf \
  build/nginx/edge-phase2.conf \
  build/firewall/backend-pf.conf; do
  if [[ ! -f "$expected" ]]; then
    echo "FAIL: missing rendered file $expected" >&2
    exit 1
  fi
done

# Verify shell script syntax across the repository
while IFS= read -r script; do
  bash -n "$script"
done < <(find . -maxdepth 3 -name '*.sh' -not -path './.git/*' | sort)

echo "PASS: render and shell syntax checks passed"
