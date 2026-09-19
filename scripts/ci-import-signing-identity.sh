#!/usr/bin/env bash
# Imports the Developer ID signing identity into a keychain of its own on
# a CI runner and proves codesign can use it. Expects SIGN_P12, the .p12
# in base64, and SIGN_P12_PASSWORD. Exports CODESIGN_IDENTITY for the
# following steps, or fails with the reason.
set -euo pipefail

: "${SIGN_P12:?DEVELOPER_ID_P12 secret missing}"
: "${SIGN_P12_PASSWORD:?DEVELOPER_ID_P12_PASSWORD secret missing}"

WORK="${RUNNER_TEMP:-/tmp}"
KEYCHAIN="$WORK/whisk-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -hex 16)"
P12="$WORK/signing.p12"
trap 'rm -f "$P12"' EXIT

echo "$SIGN_P12" | base64 --decode > "$P12"
echo "p12: $(stat -f%z "$P12") bytes"
# Structure only, never the key: the bag types tell a certificate-only
# export from a real identity.
openssl pkcs12 -info -in "$P12" -passin env:SIGN_P12_PASSWORD -nokeys -noout 2>&1 \
  | grep -E "MAC|Bag|Keybag|rror" || true

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
# No auto-lock: the universal build runs longer than the default.
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
# shellcheck disable=SC2046
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '" ')

# Apple's Developer ID intermediates complete the chain codesign verifies.
for ca in DeveloperIDCA DeveloperIDG2CA; do
  curl -fsSLo "$WORK/$ca.cer" "https://www.apple.com/certificateauthority/$ca.cer"
  security import "$WORK/$ca.cer" -k "$KEYCHAIN"
  rm "$WORK/$ca.cer"
done

security import "$P12" -k "$KEYCHAIN" -P "$SIGN_P12_PASSWORD" -f pkcs12 \
  -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" > /dev/null

security find-identity -v -p codesigning "$KEYCHAIN"
IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN" \
  | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')"
if [ -z "$IDENTITY" ]; then
  echo "no valid 'Developer ID Application' identity in the p12: was the private key exported with it?" >&2
  exit 1
fi
echo "identity: $IDENTITY"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "CODESIGN_IDENTITY=$IDENTITY" >> "$GITHUB_ENV"
fi
