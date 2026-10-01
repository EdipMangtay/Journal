#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-1.0.0}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Use a semantic version, e.g. 1.0.0.' >&2; exit 1; }
if [[ "${REQUIRE_SIGNING:-0}" == 1 || -n "${MACOS_NOTARY_PROFILE:-}" ]]; then
  [[ "${MACOS_APP_IDENTITY:-}" == 'Developer ID Application:'* && "${MACOS_INSTALLER_IDENTITY:-}" == 'Developer ID Installer:'* && -n "${MACOS_NOTARY_PROFILE:-}" ]] || {
    echo 'Trusted distribution requires Developer ID Application, Developer ID Installer and a notarytool profile.' >&2; exit 1;
  }
fi
NOTARY_ARGS=(--keychain-profile "${MACOS_NOTARY_PROFILE:-}")
if [[ -n "${MACOS_NOTARY_KEYCHAIN:-}" ]]; then NOTARY_ARGS+=(--keychain "$MACOS_NOTARY_KEYCHAIN"); fi
TASK_ROOT="$PWD/build/distribution-$VERSION"
TASK_OUTPUT="$PWD/release"
TASK_APP="$TASK_ROOT/root/Applications/Liquidity Edge.app"
mkdir -p "$TASK_ROOT/root/Applications" "$TASK_OUTPUT"
xcodebuild -quiet -project LiquidityEdge.xcodeproj -scheme LiquidityEdge \
  -configuration Release -derivedDataPath "$TASK_ROOT/DerivedData" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
  ENABLE_APP_SANDBOX=NO MARKETING_VERSION="$VERSION" build
ditto "$TASK_ROOT/DerivedData/Build/Products/Release/Liquidity Edge.app" "$TASK_APP"
TASK_ICONSET="$TASK_ROOT/AppIcon.iconset"
mkdir -p "$TASK_ICONSET" "$TASK_APP/Contents/Resources"
for size in 16 32 128 256 512; do
  for scale in 1 2; do
    suffix=''; [[ "$scale" == 2 ]] && suffix='@2x'
    sips -z "$((size * scale))" "$((size * scale))" \
      LiquidityEdge/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png \
      --out "$TASK_ICONSET/icon_${size}x${size}${suffix}.png" >/dev/null
  done
done
iconutil -c icns "$TASK_ICONSET" -o "$TASK_APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconFile' "$TASK_APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$TASK_APP/Contents/Info.plist"
SIGNING_ARGS=(--force --sign "${MACOS_APP_IDENTITY:--}")
if [[ -n "${MACOS_APP_IDENTITY:-}" ]]; then SIGNING_ARGS+=(--options runtime --timestamp); fi
codesign "${SIGNING_ARGS[@]}" "$TASK_APP"
codesign --verify --deep --strict "$TASK_APP"
if [[ -n "${MACOS_NOTARY_PROFILE:-}" ]]; then
  ditto -c -k --keepParent "$TASK_APP" "$TASK_ROOT/Notarization.zip"
  xcrun notarytool submit "$TASK_ROOT/Notarization.zip" "${NOTARY_ARGS[@]}" --wait
  xcrun stapler staple "$TASK_APP"
  xcrun stapler validate "$TASK_APP"
  spctl --assess --type execute --verbose "$TASK_APP"
fi
TASK_ARCHS="$(lipo -archs "$TASK_APP/Contents/MacOS/Liquidity Edge")"
[[ " $TASK_ARCHS " == *' arm64 '* && " $TASK_ARCHS " == *' x86_64 '* ]] || { echo 'Universal binary verification failed.' >&2; exit 1; }
pkgbuild --analyze --root "$TASK_ROOT/root" "$TASK_ROOT/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$TASK_ROOT/components.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Add :0:BundleIsRelocatable bool false' "$TASK_ROOT/components.plist"
pkgbuild --root "$TASK_ROOT/root" --component-plist "$TASK_ROOT/components.plist" \
  --identifier com.liquidityedge.journal.pkg --version "$VERSION" \
  --install-location / "$TASK_ROOT/LiquidityEdge-component.pkg"
productbuild --synthesize --product Packaging/requirements.plist --package "$TASK_ROOT/LiquidityEdge-component.pkg" "$TASK_ROOT/Distribution.xml"
PKG_ARGS=(--distribution "$TASK_ROOT/Distribution.xml" --package-path "$TASK_ROOT")
if [[ -n "${MACOS_INSTALLER_IDENTITY:-}" ]]; then PKG_ARGS+=(--sign "$MACOS_INSTALLER_IDENTITY" --timestamp); fi
TASK_PKG="$TASK_OUTPUT/Liquidity-Edge-macOS-Universal.pkg"
productbuild "${PKG_ARGS[@]}" "$TASK_PKG"
if [[ -n "${MACOS_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$TASK_PKG" "${NOTARY_ARGS[@]}" --wait
  xcrun stapler staple "$TASK_PKG"
  xcrun stapler validate "$TASK_PKG"
  spctl --assess --type install --verbose "$TASK_PKG"
fi
mkdir -p "$TASK_ROOT/dmg"
ditto "$TASK_APP" "$TASK_ROOT/dmg/Liquidity Edge.app"
ln -sfn /Applications "$TASK_ROOT/dmg/Applications"
cp ../INSTALLATION.md "$TASK_ROOT/dmg/INSTALLATION.md"
hdiutil create -ov -volname 'Liquidity Edge' -srcfolder "$TASK_ROOT/dmg" \
  -format UDZO "$TASK_OUTPUT/Liquidity-Edge-macOS-Universal.dmg"
if [[ -n "${MACOS_APP_IDENTITY:-}" ]]; then codesign --sign "$MACOS_APP_IDENTITY" --timestamp "$TASK_OUTPUT/Liquidity-Edge-macOS-Universal.dmg"; fi
if [[ -n "${MACOS_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$TASK_OUTPUT/Liquidity-Edge-macOS-Universal.dmg" "${NOTARY_ARGS[@]}" --wait
  xcrun stapler staple "$TASK_OUTPUT/Liquidity-Edge-macOS-Universal.dmg"
  xcrun stapler validate "$TASK_OUTPUT/Liquidity-Edge-macOS-Universal.dmg"
fi
(cd "$TASK_OUTPUT" && shasum -a 256 Liquidity-Edge-macOS-Universal.pkg Liquidity-Edge-macOS-Universal.dmg > SHA256SUMS-macOS.txt)
echo "Installers: $TASK_OUTPUT"
