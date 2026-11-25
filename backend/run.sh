#!/usr/bin/env bash
# usage: backend/run.sh A   (on Mac 3)   |   backend/run.sh B   (on Mac 4)
source "$(dirname "$0")/../scripts/lib.sh"
case "${1:-}" in
  A) exec python3 "$ROOT/backend/server.py" --name A --port "$PORT_A" ;;
  B) exec python3 "$ROOT/backend/server.py" --name B --port "$PORT_B" ;;
  *) echo "usage: $0 A|B"; exit 1 ;;
esac
