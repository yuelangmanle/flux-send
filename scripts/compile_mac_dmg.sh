#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_DIR/app"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
SIGN_ID="${SIGN_ID:--}"
VERSION="${VERSION:-$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$/\1/p' "$APP_DIR/pubspec.yaml" | head -n 1)}"

if [[ -z "$VERSION" ]]; then
  echo "无法从 $APP_DIR/pubspec.yaml 解析版本号；也可以通过 VERSION=1.2.3 指定。" >&2
  exit 1
fi

RELEASE_DIR="$PROJECT_DIR/releases/history/v$VERSION"
APP_BUNDLE="$APP_DIR/build/macos/Build/Products/Release/Flux.app"
ENTITLEMENTS="$APP_DIR/macos/Runner/Release.entitlements"
DMG_TMP="/tmp/flux-v$VERSION-dmg"
DMG_OUT="$RELEASE_DIR/Flux-v$VERSION-macOS.dmg"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  cat <<EOF
DRY_RUN=1
VERSION=$VERSION
RELEASE_DIR=$RELEASE_DIR
APP_BUNDLE=$APP_BUNDLE
ENTITLEMENTS=$ENTITLEMENTS
DMG_OUT=$DMG_OUT
EOF
  exit 0
fi

mkdir -p "$RELEASE_DIR"

cd "$APP_DIR"
echo "Building Flux macOS release..."
RUSTUP_DIST_SERVER="${RUSTUP_DIST_SERVER:-https://rsproxy.cn}" \
RUSTUP_UPDATE_ROOT="${RUSTUP_UPDATE_ROOT:-https://rsproxy.cn/rustup}" \
  "$FLUTTER_BIN" build macos --release

echo "Signing frameworks..."
find "$APP_BUNDLE/Contents/Frameworks" -name "*.framework" -type d -print0 | while IFS= read -r -d '' fw; do
  codesign --force --deep --sign "$SIGN_ID" "$fw"
done

echo "Signing Flux.app with release entitlements..."
codesign --force --deep --sign "$SIGN_ID" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

ENTITLEMENTS_CHECK="$(mktemp)"
codesign -d --entitlements :- "$APP_BUNDLE" >"$ENTITLEMENTS_CHECK" 2>/dev/null
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.bluetooth' "$ENTITLEMENTS_CHECK" | grep -q 'true'
rm -f "$ENTITLEMENTS_CHECK"

echo "Creating $DMG_OUT..."
rm -rf "$DMG_TMP" "$DMG_OUT"
mkdir -p "$DMG_TMP"
cp -R "$APP_BUNDLE" "$DMG_TMP/Flux.app"
ln -s /Applications "$DMG_TMP/Applications"
hdiutil create -volname "Flux" -srcfolder "$DMG_TMP" -ov -format UDZO "$DMG_OUT"
hdiutil verify "$DMG_OUT"

echo "macOS DMG ready: $DMG_OUT"
