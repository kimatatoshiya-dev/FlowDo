#!/usr/bin/env bash
# Device cold-launch verification (no Xcode LLDB).
# Usage: unlock iPhone, then: ./scripts/verify_device_launch.sh [stock|custom|profile|all]
set -euo pipefail

DEVICE="${DEVICE:-AA400743-773A-548C-AC8E-B4F3D40A32B0}"
BUNDLE=com.kimata.flowdo
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="$ROOT/.verify_logs"
BACKUP="$ROOT/.verify_backup"
mkdir -p "$LOGDIR" "$BACKUP"

launch_capture() {
  local label="$1"
  local app_path="$2"
  local out="$LOGDIR/${label}.log"
  echo ""
  echo "=== $label ==="
  xcrun devicectl device install app --device "$DEVICE" "$app_path" 2>&1 | tail -3
  xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE" --terminate-existing 2>&1 | tail -2 || true
  sleep 3
  perl -e 'alarm shift; exec @ARGV' 20 xcrun devicectl device process launch \
    --device "$DEVICE" "$BUNDLE" --console >"$out" 2>&1 || true
  echo "log: $out ($(wc -c <"$out" | tr -d ' ') bytes)"
  rg -i "FlowDoStartupProbe|StandardProbe|Cannot create|SIGSEGV|VSync|FlutterEngine|build mode|main\\(\\)|Locked|crash|EXC_|flutter:" "$out" | head -40 || echo "(no key matches)"
}

apply_stock_native() {
  cp "$ROOT/ios/Runner/AppDelegate.swift" "$BACKUP/AppDelegate.swift" 2>/dev/null || true
  cp "$ROOT/ios/Runner/Base.lproj/Main.storyboard" "$BACKUP/Main.storyboard" 2>/dev/null || true
  cp "$ROOT/ios/Runner.xcodeproj/project.pbxproj" "$BACKUP/project.pbxproj" 2>/dev/null || true
  cp "$ROOT/ios/Runner/Runner-Bridging-Header.h" "$BACKUP/Runner-Bridging-Header.h" 2>/dev/null || true
  git -C "$ROOT" show efc64a1:ios/Runner/AppDelegate.swift >"$ROOT/ios/Runner/AppDelegate.swift"
  git -C "$ROOT" show efc64a1:ios/Runner/Base.lproj/Main.storyboard >"$ROOT/ios/Runner/Base.lproj/Main.storyboard"
  git -C "$ROOT" show efc64a1:ios/Runner.xcodeproj/project.pbxproj >"$ROOT/ios/Runner.xcodeproj/project.pbxproj"
  git -C "$ROOT" show efc64a1:ios/Runner/Runner-Bridging-Header.h >"$ROOT/ios/Runner/Runner-Bridging-Header.h"
}

restore_custom_native() {
  [[ -f "$BACKUP/AppDelegate.swift" ]] || return 0
  cp "$BACKUP/AppDelegate.swift" "$ROOT/ios/Runner/AppDelegate.swift"
  cp "$BACKUP/Main.storyboard" "$ROOT/ios/Runner/Base.lproj/Main.storyboard"
  cp "$BACKUP/project.pbxproj" "$ROOT/ios/Runner.xcodeproj/project.pbxproj"
  cp "$BACKUP/Runner-Bridging-Header.h" "$ROOT/ios/Runner/Runner-Bridging-Header.h"
}

run_stock() {
  apply_stock_native
  (cd "$ROOT" && flutter build ios --debug)
  launch_capture "flowdo_debug_stock_native" "$ROOT/build/ios/iphoneos/Runner.app"
  restore_custom_native
}

run_custom_debug() {
  restore_custom_native
  (cd "$ROOT" && flutter build ios --debug)
  launch_capture "flowdo_debug_custom_native" "$ROOT/build/ios/iphoneos/Runner.app"
}

run_profile() {
  restore_custom_native
  (cd "$ROOT" && flutter build ios --profile)
  launch_capture "flowdo_profile_custom_native" "$ROOT/build/ios/iphoneos/Runner.app"
}

mode="${1:-all}"
case "$mode" in
  stock) run_stock ;;
  custom) run_custom_debug ;;
  profile) run_profile ;;
  all)
    run_stock
    run_custom_debug
    run_profile
    ;;
  *) echo "usage: $0 [stock|custom|profile|all]" >&2; exit 1 ;;
esac

echo ""
echo "Done. Logs in $LOGDIR"
