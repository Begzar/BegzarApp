#!/usr/bin/env bash
# Print APK signing certificate SHA-256 (lowercase hex, no colons).
#
# Usage:
#   ./scripts/extract_apk_signing_cert.sh path/to/app.apk
#   adb shell pm path cloud.begzar.begzar | cut -d: -f2 | xargs -I{} adb pull {} /tmp/play.apk && ./scripts/extract_apk_signing_cert.sh /tmp/play.apk
#
# Add the output to android/gradle.properties:
#   playAppSigningCertSha256=<hex>
#
set -euo pipefail

APK="${1:?APK path required}"

if command -v apksigner >/dev/null 2>&1; then
  apksigner verify --print-certs "$APK" | awk -F': ' '/Signer #1 certificate SHA-256 digest:/ {print $2; exit}' | tr -d ':'
  exit 0
fi

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
APKSIGNER="$(find "$SDK/build-tools" -name apksigner 2>/dev/null | sort -V | tail -1 || true)"
if [[ -n "$APKSIGNER" ]]; then
  "$APKSIGNER" verify --print-certs "$APK" | awk -F': ' '/Signer #1 certificate SHA-256 digest:/ {print $2; exit}' | tr -d ':'
  exit 0
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
unzip -q -j "$APK" 'META-INF/*.RSA' 'META-INF/*.DSA' 'META-INF/*.EC' -d "$TMPDIR" 2>/dev/null || true
CERT="$(find "$TMPDIR" -type f | head -1)"
[[ -n "$CERT" ]] || { echo "Could not extract signing cert from $APK" >&2; exit 1; }
openssl pkcs7 -inform DER -in "$CERT" -print_certs -out "$TMPDIR/cert.pem" 2>/dev/null
openssl x509 -in "$TMPDIR/cert.pem" -noout -fingerprint -sha256 | awk -F= '{print tolower($2)}' | tr -d ':'
