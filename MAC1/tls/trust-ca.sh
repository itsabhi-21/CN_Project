#!/usr/bin/env bash
# Run on EVERY client Mac: adds the team CA to the System keychain.
# Safari/Chrome use it. Firefox: Settings > Certificates > Import ca.crt.
source "$(dirname "$0")/../scripts/lib.sh"
case "${1:-add}" in
  add)    sudo security add-trusted-cert -d -r trustRoot \
              -k /Library/Keychains/System.keychain "$CA" && echo "CA trusted" ;;
  remove) sudo security remove-trusted-cert -d "$CA" && echo "trust removed" ;;
esac
