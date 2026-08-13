#!/usr/bin/env bash
# 【調査・リリース前専用】通常開発では使わない（README 参照）
# 実機永続化 20 回検証: 追加 → 完全終了 → コールド起動 → SP 復元確認
# devicectl install を使うため、通常開発フロー（flutter run / Xcode Run）とは分離すること
#
# 用法: ALLOW_VERIFY=1 ./scripts/verify_persist_20x.sh
set -euo pipefail

if [[ "${ALLOW_VERIFY:-0}" != "1" ]]; then
  echo "ERROR: 調査・リリース前検証専用です。通常開発は flutter run または Xcode Run を使ってください." >&2
  echo "実行する場合: ALLOW_VERIFY=1 $0" >&2
  exit 1
fi

FLUTTER_DEVICE="${FLUTTER_DEVICE:-00008150-001529913640C01C}"
DEVICECTL_DEVICE="${DEVICECTL_DEVICE:-AA400743-773A-548C-AC8E-B4F3D40A32B0}"
BUNDLE="${BUNDLE:-com.kimata.flowdo}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="$ROOT/.verify_logs/persist_20x"
PROFILE_APP="$ROOT/build/ios/Profile-iphoneos/Runner.app"
IPHONEOS_DIR="$ROOT/build/ios/iphoneos"
mkdir -p "$LOGDIR" "$IPHONEOS_DIR"

CYCLES=20
SUCCESS=0
LAUNCH_WAIT="${LAUNCH_WAIT:-20}"

ensure_app_paths() {
  if [[ -d "$PROFILE_APP" ]]; then
    ln -sfn "$PROFILE_APP" "$IPHONEOS_DIR/Runner.app"
  fi
}

pull_prefs_plist() {
  local dest="$1"
  rm -f "$dest"
  xcrun devicectl device copy from \
    --device "$DEVICECTL_DEVICE" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE" \
    --source "Library/Preferences/${BUNDLE}.plist" \
    --destination "$dest" 2>/dev/null
}

marker_in_prefs() {
  local plist="$1"
  local marker="$2"
  [[ -f "$plist" ]] || return 1
  [[ "$(wc -c <"$plist" | tr -d ' ')" -gt 80 ]] || return 1
  strings "$plist" | rg -q "flowdo_tasks" || return 1
  if [[ -n "$marker" ]]; then
    strings "$plist" | rg -q "$marker"
  else
    strings "$plist" | rg -q "persist-verify-"
  fi
}

launch_app() {
  local marker="$1"
  local env_json
  env_json=$(MARKER="$marker" python3 -c 'import json,os; print(json.dumps({"FLOWDO_PERSIST_MARKER": os.environ["MARKER"]}))')
  xcrun devicectl device process launch \
    --device "$DEVICECTL_DEVICE" \
    --environment-variables "$env_json" \
    --terminate-existing \
    "$BUNDLE" --persist-marker="$marker" 2>&1
}

echo "=== FlowDo persist 20x (plist verification) ==="
echo "device(flutter)=$FLUTTER_DEVICE device(devicectl)=$DEVICECTL_DEVICE"

cd "$ROOT"
flutter pub get >/dev/null
ensure_app_paths

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  echo "Building profile (PERSIST_DEVICE_VERIFY)..."
  flutter build ios --profile \
    --dart-define=PERSIST_DEVICE_VERIFY=true \
    --dart-define=PERSIST_VERIFY_ONLY=true \
    -d "$FLUTTER_DEVICE" 2>&1 | tail -5
  ensure_app_paths
fi

if [[ ! -d "$PROFILE_APP" ]]; then
  echo "FAIL: $PROFILE_APP not found"
  exit 1
fi

if [[ "${SKIP_INSTALL:-0}" != "1" ]]; then
  echo "Installing (devicectl, no flutter uninstall)..."
  xcrun devicectl device install app --device "$DEVICECTL_DEVICE" "$PROFILE_APP" 2>&1 | tail -3
fi

# 起動可否チェック
if ! launch_app "persist-probe" 2>&1 | rg -q "Launched application"; then
  echo ""
  echo "WARN: devicectl launch failed (開発者プロファイル未信頼の可能性)"
  echo "  設定 > 一般 > VPNとデバイス管理 で開発者を信頼後、再実行してください"
  echo "  または Xcode から1回 Run してから SKIP_INSTALL=1 で再実行"
  exit 2
fi
xcrun devicectl device process terminate --device "$DEVICECTL_DEVICE" "$BUNDLE" 2>/dev/null || true
sleep 2

for ((i = 1; i <= CYCLES; i++)); do
  echo ""
  echo "--- Cycle $i/$CYCLES ---"

  ADD_LOG="$LOGDIR/cycle_${i}_add.log"
  if ! launch_app "persist-cycle-${i}" >"$ADD_LOG" 2>&1; then
    echo "FAIL cycle $i: launch (add)"
    tail -5 "$ADD_LOG" || true
    continue
  fi
  sleep "$LAUNCH_WAIT"

  PREFS_ADD="$LOGDIR/cycle_${i}_add.plist"
  if ! pull_prefs_plist "$PREFS_ADD"; then
    echo "FAIL cycle $i: prefs pull (add)"
    continue
  fi
  MARKER=$(strings "$PREFS_ADD" | rg -o 'persist-(verify|cycle)-[0-9]+' | tail -1 || true)
  if [[ -z "$MARKER" ]] || ! marker_in_prefs "$PREFS_ADD" "$MARKER"; then
    echo "FAIL cycle $i: marker not in SP after add (size=$(wc -c <"$PREFS_ADD" | tr -d ' '))"
    continue
  fi
  echo "  add: SP ok marker=$MARKER"

  xcrun devicectl device process terminate --device "$DEVICECTL_DEVICE" "$BUNDLE" 2>/dev/null || true
  sleep 2

  LAUNCH_LOG="$LOGDIR/cycle_${i}_launch.log"
  if ! launch_app "$MARKER" >"$LAUNCH_LOG" 2>&1; then
    echo "FAIL cycle $i: launch (cold)"
    tail -5 "$LAUNCH_LOG" || true
    continue
  fi
  sleep "$LAUNCH_WAIT"

  PREFS_LAUNCH="$LOGDIR/cycle_${i}_launch.plist"
  if ! pull_prefs_plist "$PREFS_LAUNCH"; then
    echo "FAIL cycle $i: prefs pull (launch)"
    continue
  fi
  if marker_in_prefs "$PREFS_LAUNCH" "$MARKER"; then
    echo "  launch: restore ok marker=$MARKER"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "FAIL cycle $i: marker missing after cold launch"
  fi

  xcrun devicectl device process terminate --device "$DEVICECTL_DEVICE" "$BUNDLE" 2>/dev/null || true
  sleep 1
done

echo ""
echo "=== RESULT: $SUCCESS / $CYCLES ==="
echo "[FlowDoPersistResult] success=$SUCCESS/$CYCLES" | tee "$LOGDIR/summary.txt"
[[ "$SUCCESS" -eq "$CYCLES" ]]
