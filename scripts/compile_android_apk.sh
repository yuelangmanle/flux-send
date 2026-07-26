#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_DIR/app"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
VERSION="${VERSION:-$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$/\1/p' "$APP_DIR/pubspec.yaml" | head -n 1)}"

if [[ -z "$VERSION" ]]; then
  echo "无法从 $APP_DIR/pubspec.yaml 解析版本号；也可以通过 VERSION=1.2.3 指定。" >&2
  exit 1
fi

RELEASE_DIR="$PROJECT_DIR/releases/history/v$VERSION"
APK_SOURCE="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
APK_OUT="$RELEASE_DIR/Flux-v$VERSION-android.apk"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  cat <<EOF
DRY_RUN=1
VERSION=$VERSION
RELEASE_DIR=$RELEASE_DIR
APK_SOURCE=$APK_SOURCE
APK_OUT=$APK_OUT
EOF
  exit 0
fi

mkdir -p "$RELEASE_DIR"

cd "$APP_DIR"
echo "Building Flux Android release APK..."
RUSTUP_DIST_SERVER="${RUSTUP_DIST_SERVER:-https://rsproxy.cn}" \
RUSTUP_UPDATE_ROOT="${RUSTUP_UPDATE_ROOT:-https://rsproxy.cn/rustup}" \
  "$FLUTTER_BIN" build apk --release

cp "$APK_SOURCE" "$APK_OUT"
echo "Android APK ready: $APK_OUT"
