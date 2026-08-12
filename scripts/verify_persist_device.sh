#!/usr/bin/env bash
# 実機で永続化3点（storageReady / save / restart）を integration_test で確認する。
set -euo pipefail

DEVICE_ID="${1:-00008150-001529913640C01C}"
DART_DEFINE="--dart-define=FLOWDO_VERIFY_PERSIST=true"

cd "$(dirname "$0")/.."
flutter pub get >/dev/null

kill_runner() {
  local pids
  pids=$(xcrun devicectl device info processes --device "$DEVICE_ID" 2>/dev/null \
    | rg "Runner\.app/Runner" | awk '{print $1}' || true)
  for pid in $pids; do
    xcrun devicectl device process signal \
      --device "$DEVICE_ID" --pid "$pid" --signal SIGKILL 2>/dev/null || true
  done
  sleep 2
}

echo "==> Integration test 1: save"
kill_runner
flutter test integration_test/persist_save_test.dart \
  -d "$DEVICE_ID" $DART_DEFINE

echo "==> Cold restart"
kill_runner
sleep 2

echo "==> Integration test 2: restart restore"
flutter test integration_test/persist_restart_test.dart \
  -d "$DEVICE_ID" $DART_DEFINE

echo "PASS: all persistence checks succeeded on device"
