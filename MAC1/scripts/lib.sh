# shared helpers - sourced by other scripts
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/config.env"
CA="$ROOT/tls/out/ca.crt"
CURL=(curl -s --connect-timeout 3)
# If system curl doesn't read the macOS keychain, run with USE_CACERT=1.
# --cacert still VERIFIES the certificate (unlike -k), so it is allowed.
[[ "${USE_CACERT:-0}" == 1 ]] && CURL+=(--cacert "$CA")
PSFX=""; [[ "$HTTPS_PORT" != 443 ]] && PSFX=":$HTTPS_PORT"
BASE="https://app.$TEAM.test$PSFX"
hr(){ printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
