#!/usr/bin/env bash
#
# One-time setup: creates a local, self-signed code-signing certificate named
# "NiCoLpy Local" in your login keychain.
#
# Why: macOS ties Accessibility permission to an app's signing identity. A plain
# ad-hoc signature changes on every build, so the OS forgets the permission each
# time you update NiCoLpy. Signing with a stable local identity keeps the
# permission across updates — you grant Accessibility once and never again.
#
# This certificate is local to your Mac, is NOT a security risk, and can be
# removed any time from Keychain Access (search for "NiCoLpy Local").
#
set -euo pipefail

IDENTITY="NiCoLpy Local"
LOGIN_KC="$HOME/Library/Keychains/login.keychain-db"

GREEN="$(tput setaf 2 2>/dev/null || true)"
BOLD="$(tput bold 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script is only for macOS." >&2
    exit 1
fi

# Already set up? Nothing to do.
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    echo "${GREEN}✓${RESET} Signing identity '$IDENTITY' already exists. Nothing to do."
    exit 0
fi

echo "==> Creating a local code-signing certificate '$IDENTITY'..."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# OpenSSL config with the codeSigning extended key usage.
cat > "$WORK/cert.cnf" <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions = v3_codesign
prompt = no

[ dn ]
CN = NiCoLpy Local

[ v3_codesign ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# Key + self-signed cert (valid 10 years).
openssl req -x509 -newkey rsa:2048 \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
    -days 3650 -nodes -config "$WORK/cert.cnf" >/dev/null 2>&1

# Bundle into a .p12 for keychain import.
openssl pkcs12 -export \
    -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -out "$WORK/identity.p12" -name "$IDENTITY" \
    -passout pass:nicolpy >/dev/null 2>&1

# Import, allowing codesign to use the private key without prompting each time.
security import "$WORK/identity.p12" \
    -k "$LOGIN_KC" -P nicolpy \
    -T /usr/bin/codesign >/dev/null 2>&1

echo "${GREEN}${BOLD}Done!${RESET} '$IDENTITY' is ready."
echo "Future builds will use it automatically, so the Accessibility"
echo "permission you grant NiCoLpy will survive updates."
