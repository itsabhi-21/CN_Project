#!/usr/bin/env bash
# Creates a private team CA + a server certificate for app/api.<team>.test
# Run ONCE (on Mac 2). Then copy tls/out/ca.crt to every client Mac.
# Never share ca.key.
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
OUT="$ROOT/tls/out"; mkdir -p "$OUT"; cd "$OUT"

cat > ca.cnf <<EOF
[req]
distinguished_name = dn
prompt = no
[dn]
CN = ${TEAM} Local Root CA
O  = CN Project ${TEAM}
[v3_ca]
basicConstraints     = critical, CA:TRUE
keyUsage             = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
EOF

cat > server.ext <<EOF
basicConstraints       = CA:FALSE
keyUsage               = critical, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth
subjectAltName         = DNS:app.${TEAM}.test, DNS:api.${TEAM}.test
authorityKeyIdentifier = keyid
EOF

# 1) Certificate Authority (self-signed root)
openssl genrsa -out ca.key 4096
openssl req -x509 -new -key ca.key -sha256 -days 825 \
        -config ca.cnf -extensions v3_ca -out ca.crt

# 2) Server key + CSR + certificate signed by the CA
#    (macOS requires: SAN present, EKU serverAuth, validity <= 825 days)
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=app.${TEAM}.test" -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
        -days 397 -sha256 -extfile server.ext -out server.crt

echo; openssl x509 -in server.crt -noout -subject -issuer -dates -ext subjectAltName
echo; openssl verify -CAfile ca.crt server.crt
