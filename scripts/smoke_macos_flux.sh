#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${APP_PATH:-/Applications/Flux.app}"
APP_NAME="${APP_NAME:-Flux}"
FLUX_SMOKE_MODE="${FLUX_SMOKE_MODE:-}"
SMOKE_SECONDS="${SMOKE_SECONDS:-12}"
KEEP_RUNNING="${KEEP_RUNNING:-0}"
REQUIRE_TCP_LISTEN="${REQUIRE_TCP_LISTEN:-1}"
DIAGNOSTIC_DIR="$HOME/Library/Logs/DiagnosticReports"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  cat <<EOF
DRY_RUN=1
APP_PATH=$APP_PATH
APP_NAME=$APP_NAME
FLUX_SMOKE_MODE=${FLUX_SMOKE_MODE:-none}
SMOKE_SECONDS=$SMOKE_SECONDS
REQUIRE_TCP_LISTEN=$REQUIRE_TCP_LISTEN
SUPPORTED_MODES=localNetwork,hotspot,classicBluetooth
CHECKS=process,CGWindowListCopyWindowInfo,Flux-*.ips,flutter.flux_connection_mode,localNetwork,hotspot,classicBluetooth,lsof,-iTCP,-sTCP:LISTEN
EOF
  exit 0
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "找不到 macOS 应用：$APP_PATH" >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
PREF="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Preferences/$BUNDLE_ID.plist"
PREF_BACKUP=""
PREF_EXISTED=0
WINDOW_SCRIPT="$(mktemp /tmp/flux-window-smoke.XXXXXX.swift)"

quit_flux() {
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  sleep 1
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

restore_pref() {
  if [[ -z "$PREF_BACKUP" ]]; then
    return
  fi
  if [[ "$PREF_EXISTED" == "1" ]]; then
    cp "$PREF_BACKUP" "$PREF"
  else
    rm -f "$PREF"
  fi
  killall cfprefsd >/dev/null 2>&1 || true
}

cleanup() {
  if [[ "$KEEP_RUNNING" != "1" ]]; then
    quit_flux
  fi
  restore_pref
  rm -f "$WINDOW_SCRIPT" "$PREF_BACKUP"
}
trap cleanup EXIT

cat >"$WINDOW_SCRIPT" <<'SWIFT'
import Foundation
import CoreGraphics

let appName = CommandLine.arguments.dropFirst().first ?? "Flux"
let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
var visibleWindows = 0

for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    guard owner == appName else {
        continue
    }

    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    let alpha = window[kCGWindowAlpha as String] as? Double ?? 0
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Double ?? 0
    let height = bounds["Height"] as? Double ?? 0

    if layer == 0 && alpha > 0 && width > 0 && height > 0 {
        visibleWindows += 1
    }
}

print(visibleWindows)
SWIFT

quit_flux

if [[ -n "$FLUX_SMOKE_MODE" ]]; then
  case "$FLUX_SMOKE_MODE" in
    localNetwork|hotspot|classicBluetooth) ;;
    *)
      echo "不支持的 FLUX_SMOKE_MODE：$FLUX_SMOKE_MODE；只支持 localNetwork / hotspot / classicBluetooth" >&2
      exit 1
      ;;
  esac

  PREF_BACKUP="$(mktemp /tmp/flux-pref-backup.XXXXXX.plist)"
  if [[ -f "$PREF" ]]; then
    PREF_EXISTED=1
    cp "$PREF" "$PREF_BACKUP"
  else
    mkdir -p "$(dirname "$PREF")"
    cat >"$PREF" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST
  fi

  /usr/libexec/PlistBuddy -c "Set :flutter.flux_connection_mode $FLUX_SMOKE_MODE" "$PREF" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :flutter.flux_connection_mode string $FLUX_SMOKE_MODE" "$PREF"
  killall cfprefsd >/dev/null 2>&1 || true
  echo "已设置烟测连接模式：$FLUX_SMOKE_MODE"
fi

CRASH_BEFORE="$(find "$DIAGNOSTIC_DIR" -maxdepth 1 -name 'Flux-*.ips' -print 2>/dev/null | wc -l | tr -d ' ')"
echo "crash_reports_before=$CRASH_BEFORE"

open -a "$APP_PATH"
sleep "$SMOKE_SECONDS"

if ! pgrep -x "$APP_NAME" >/dev/null; then
  echo "$APP_NAME 启动后未保持运行" >&2
  exit 1
fi
echo "$APP_NAME process running after ${SMOKE_SECONDS}s"

VISIBLE_WINDOWS="$(swift "$WINDOW_SCRIPT" "$APP_NAME" | tail -n 1 | tr -d '[:space:]')"
echo "visible_windows=$VISIBLE_WINDOWS"
if [[ "${VISIBLE_WINDOWS:-0}" -lt 1 ]]; then
  echo "$APP_NAME 未枚举到可见主窗口" >&2
  exit 1
fi

if [[ -n "$FLUX_SMOKE_MODE" ]]; then
  CURRENT_MODE="$(/usr/libexec/PlistBuddy -c 'Print :flutter.flux_connection_mode' "$PREF" 2>/dev/null || true)"
  echo "flux_connection_mode=$CURRENT_MODE"
  if [[ "$CURRENT_MODE" != "$FLUX_SMOKE_MODE" ]]; then
    echo "连接模式未保持为 $FLUX_SMOKE_MODE，当前为 ${CURRENT_MODE:-空}" >&2
    exit 1
  fi
fi

if [[ "$REQUIRE_TCP_LISTEN" == "1" ]]; then
  TCP_LISTEN="$(lsof -nP -a -c "$APP_NAME" -iTCP -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -z "$TCP_LISTEN" ]]; then
    echo "$APP_NAME 没有检测到 TCP LISTEN；局域网/热点文件接收与剪切板接收服务可能未启动" >&2
    exit 1
  fi
  echo "tcp_listen_ok=1"
  echo "$TCP_LISTEN" | sed 's/^/  /'
fi

CRASH_AFTER="$(find "$DIAGNOSTIC_DIR" -maxdepth 1 -name 'Flux-*.ips' -print 2>/dev/null | wc -l | tr -d ' ')"
echo "crash_reports_after=$CRASH_AFTER"
if [[ "$CRASH_AFTER" != "$CRASH_BEFORE" ]]; then
  echo "检测到新的 Flux 崩溃日志" >&2
  find "$DIAGNOSTIC_DIR" -maxdepth 1 -name 'Flux-*.ips' -print -exec stat -f '%Sm %N' {} \; 2>/dev/null | tail -n 20 >&2
  exit 1
fi

echo "macOS Flux smoke test passed"
