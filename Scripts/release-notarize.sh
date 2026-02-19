#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
umask 077

required_env=(
  APPLE_TEAM_ID
  ASC_KEY_ID
  ASC_ISSUER_ID
  ASC_API_KEY_P8_BASE64
  DEVELOPER_ID_APP_CERT_P12_BASE64
  DEVELOPER_ID_APP_CERT_PASSWORD
  KEYCHAIN_PASSWORD
)

for key in "${required_env[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    echo "Missing required environment variable: $key" >&2
    exit 1
  fi
done

VERSION_LABEL="${1:-local-$(date +%Y%m%d-%H%M%S)}"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
KEYCHAIN_PATH="$BUILD_DIR/release.keychain-db"
CERT_PATH="$BUILD_DIR/dev_id_app.p12"
NOTARY_KEY_PATH="$BUILD_DIR/AuthKey_${ASC_KEY_ID}.p8"
ARCHIVE_PATH="$BUILD_DIR/AwakeBar.xcarchive"
APP_PATH="$BUILD_DIR/AwakeBar.app"
ZIP_UNSIGNED="$BUILD_DIR/AwakeBar-unsigned.zip"
ZIP_FINAL="$DIST_DIR/AwakeBar-${VERSION_LABEL}-macos.zip"

ORIGINAL_KEYCHAINS=()
while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%\"}"
  line="${line#\"}"
  [[ -n "$line" ]] && ORIGINAL_KEYCHAINS+=("$line")
done < <(security list-keychains -d user)

LOGIN_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
if [[ -f "$LOGIN_KEYCHAIN" ]]; then
  has_login_keychain=0
  for keychain in "${ORIGINAL_KEYCHAINS[@]}"; do
    if [[ "$keychain" == "$LOGIN_KEYCHAIN" ]]; then
      has_login_keychain=1
      break
    fi
  done
  if [[ $has_login_keychain -eq 0 ]]; then
    ORIGINAL_KEYCHAINS+=("$LOGIN_KEYCHAIN")
  fi
fi

cleanup() {
  rm -f "$CERT_PATH" "$NOTARY_KEY_PATH"
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  if [[ ${#ORIGINAL_KEYCHAINS[@]} -gt 0 ]]; then
    security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1 || true
  elif [[ -f "$LOGIN_KEYCHAIN" ]]; then
    security list-keychains -d user -s "$LOGIN_KEYCHAIN" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

mkdir -p "$BUILD_DIR" "$DIST_DIR"
rm -rf "$ARCHIVE_PATH" "$APP_PATH" "$ZIP_UNSIGNED"
security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
rm -f "$KEYCHAIN_PATH"

echo "$DEVELOPER_ID_APP_CERT_P12_BASE64" | base64 --decode > "$CERT_PATH"
echo "$ASC_API_KEY_P8_BASE64" | base64 --decode > "$NOTARY_KEY_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$DEVELOPER_ID_APP_CERT_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
if [[ ${#ORIGINAL_KEYCHAINS[@]} -gt 0 ]]; then
  security list-keychains -d user -s "$KEYCHAIN_PATH" "${ORIGINAL_KEYCHAINS[@]}"
else
  security list-keychains -d user -s "$KEYCHAIN_PATH"
fi
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH"

if ! security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -Eq "Developer ID Application: .*\(${APPLE_TEAM_ID}\)"; then
  echo "Missing required signing identity: Developer ID Application for team ${APPLE_TEAM_ID}." >&2
  echo "Export a .p12 that contains Developer ID Application (not Apple Development)." >&2
  exit 1
fi

xcrun notarytool history \
  --key "$NOTARY_KEY_PATH" \
  --key-id "$ASC_KEY_ID" \
  --issuer "$ASC_ISSUER_ID" \
  --output-format json >/dev/null

xcodegen generate

xcodebuild \
  -project AwakeBar.xcodeproj \
  -scheme AwakeBar \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  AWAKEBAR_TEAM_ID="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH"

ditto "$ARCHIVE_PATH/Products/Applications/AwakeBar.app" "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type exec --verbose=4 "$APP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_UNSIGNED"

xcrun notarytool submit "$ZIP_UNSIGNED" \
  --key "$NOTARY_KEY_PATH" \
  --key-id "$ASC_KEY_ID" \
  --issuer "$ASC_ISSUER_ID" \
  --wait

xcrun stapler staple "$APP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_FINAL"
shasum -a 256 "$ZIP_FINAL" > "$ZIP_FINAL.sha256"

echo "Notarized release artifact:"
echo "  $ZIP_FINAL"
echo "Checksum:"
echo "  $ZIP_FINAL.sha256"
