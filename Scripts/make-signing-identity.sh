#!/bin/bash
# Creates a self-signed code-signing certificate for Beacon, once.
#
# Why this exists: an ad-hoc signature (`codesign -s -`) is derived from the
# binary, so it changes on every build. macOS ties privacy grants to the
# signature, so every rebuild looked like a brand-new app and silently lost
# access to Reminders and Notifications. A stable certificate keeps one identity
# across builds, so the grants stick.
set -euo pipefail
umask 077

NAME="Beacon Dev"

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "Signing identity \"$NAME\" already exists."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<CNF
[ req ]
distinguished_name = dn
prompt = no
x509_extensions = v3

[ dn ]
CN = $NAME

[ v3 ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/openssl.cnf" 2>/dev/null

# -legacy: the modern PKCS#12 cipher OpenSSL 3 defaults to is one macOS's
# keychain importer cannot read, which fails as a bogus "wrong password".
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$NAME" -out "$TMP/identity.p12" -passout pass:beacon 2>/dev/null

security import "$TMP/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P beacon -T /usr/bin/codesign

echo "Created signing identity \"$NAME\"."
echo
echo "The first build will ask for your login keychain password."
echo "Click \"Always Allow\", not \"Allow\" — \"Allow\" grants a single use, so"
echo "the prompt returns on every build."
echo
echo "If it keeps returning, grant codesign standing access to the key:"
echo "  security set-key-partition-list -S apple-tool:,apple: -s \\"
echo "    -k <your login password> ~/Library/Keychains/login.keychain-db"
echo
echo "Rebuild with ./Scripts/build-mac-app.sh — grants will now survive rebuilds."
