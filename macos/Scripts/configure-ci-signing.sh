#!/bin/bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_OS:-}" == macOS && -n "${RUNNER_TEMP:-}" ]] || { echo 'This script is only for an ephemeral GitHub macOS runner.' >&2; exit 1; }
for name in MACOS_CERTIFICATES_P12 MACOS_CERTIFICATE_PASSWORD MACOS_APP_IDENTITY MACOS_INSTALLER_IDENTITY APPLE_ID APPLE_TEAM_ID APPLE_APP_PASSWORD; do
  [[ -n "${!name:-}" ]] || { echo "Missing signing secret: $name" >&2; exit 1; }
done
umask 077
certificate="$RUNNER_TEMP/liquidity-edge-signing.p12"
keychain="$RUNNER_TEMP/liquidity-edge-signing.keychain-db"
password="$(openssl rand -hex 32)"
trap 'rm -f "$certificate"' EXIT
printf '%s' "$MACOS_CERTIFICATES_P12" | /usr/bin/base64 --decode > "$certificate"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$certificate" -k "$keychain" -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/productbuild
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
xcrun notarytool store-credentials LiquidityEdgeRelease --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --keychain "$keychain"
printf 'MACOS_NOTARY_PROFILE=LiquidityEdgeRelease\n' >> "$GITHUB_ENV"
printf 'MACOS_NOTARY_KEYCHAIN=%s\n' "$keychain" >> "$GITHUB_ENV"
