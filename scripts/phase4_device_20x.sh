#!/usr/bin/env bash
# Phase 4 実機 20 回検証（README Definition of Done）
# ① flutter run で信頼済みインストール → ② 追加→完全終了→コールド起動→SP復元 ×20
#
# VM Service が iOS 26.x で接続できない場合、integration test の代わりに
# PERSIST_DEVICE_VERIFY + devicectl 起動 + plist 確認を使う（永続化経路の検証）。
#
# 用法: iPhone 解除・開発者信頼済みで
#   ./scripts/phase4_device_20x.sh
set -euo pipefail

FLUTTER_DEVICE="${FLUTTER_DEVICE:-00008150-001529913640C01C}"
DEVICECTL_DEVICE="${DEVICECTL_DEVICE:-AA400743-773A-548C-AC8E-B4F3D40A32B0}"
BUNDLE="${BUNDLE:-com.kimata.flowdo}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="$ROOT/.verify_logs/phase4_20x"
mkdir -p "$LOGDIR"

CYCLES=20
SUCCESS=0
LAUNCH_WAIT="${LAUNCH_WAIT:-35}"
USE_INTEGRATION="${USE_INTEGRATION:-0}"

pull_prefs() {
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
  plutil -p "$plist" 2>/dev/null | rg -q "flutter.flowdo_tasks" || return 1
  plutil -p "$plist" 2>/dev/null | rg -q "$marker"
}

extract_latest_task_marker() {
  local plist="$1"
  plutil -p "$plist" 2>/dev/null \
    | rg -o 'persist-verify-[0-9]+|phase4-[0-9]+-[0-9]+|persist-cycle-[0-9]+' \
    | tail -1
}

launch_with_marker() {
  local marker="$1"
  local env_json
  env_json=$(MARKER="$marker" python3 -c 'import json,os; print(json.dumps({"FLOWDO_PERSIST_MARKER": os.environ["MARKER"]}))')
  xcrun devicectl device process launch \
    --device "$DEVICECTL_DEVICE" \
    --environment-variables "$env_json" \
    --terminate-existing \
    "$BUNDLE" --persist-marker="$marker" 2>&1
}

stop_app() {
  xcrun devicectl device process launch \
    --device "$DEVICECTL_DEVICE" \
    --terminate-existing \
    "$BUNDLE" --start-stopped 2>/dev/null || true
}

ensure_runner_symlink() {
  mkdir -p "$ROOT/build/ios/iphoneos"
  for dir in Profile-iphoneos Debug-iphoneos Release-iphoneos; do
    if [[ -d "$ROOT/build/ios/$dir/Runner.app" ]]; then
      ln -sfn "$ROOT/build/ios/$dir/Runner.app" "$ROOT/build/ios/iphoneos/Runner.app"
      return 0
    fi
  done
  return 1
}

cd "$ROOT"
flutter pub get >/dev/null

if [[ "${SKIP_FLUTTER_RUN:-0}" != "1" ]]; then
  echo "=== Step 1: flutter run (profile) で信頼済みインストール ==="
  echo "PERSIST_DEVICE_VERIFY ビルド（VM Service 未接続でもインストール完了を期待）"
  perl -e 'alarm shift; exec @ARGV' 240 \
    flutter run --profile -d "$FLUTTER_DEVICE" --no-pub \
    --dart-define=PERSIST_DEVICE_VERIFY=true \
    --dart-define=PERSIST_VERIFY_ONLY=true \
    2>&1 | tee "$LOGDIR/flutter_run.log" || true
  ensure_runner_symlink || true
  echo ""
fi

echo "=== Step 2: 20 サイクル検証 (mode=$([[ "$USE_INTEGRATION" == "1" ]] && echo integration || echo devicectl+plist)) ==="

for ((i = 1; i <= CYCLES; i++)); do
  MARKER="phase4-${i}-$(date +%s)"
  echo ""
  echo "--- Cycle $i/$CYCLES marker=$MARKER ---"

  if [[ "$USE_INTEGRATION" == "1" ]]; then
    ADD_LOG="$LOGDIR/cycle_${i}_add.log"
    ensure_runner_symlink || true
    if ! flutter test integration_test/persist_add_task_test.dart \
      -d "$FLUTTER_DEVICE" \
      --dart-define="PERSIST_MARKER=$MARKER" \
      --ignore-timeouts \
      --no-uninstall \
      2>&1 | tee "$ADD_LOG" | tail -5; then
      echo "FAIL cycle $i: flutter test add step"
      rg -i "error|fail|Exception" "$ADD_LOG" | tail -5 || true
      continue
    fi
    if ! rg -q "save_ok marker=$MARKER" "$ADD_LOG"; then
      echo "FAIL cycle $i: save_ok not in log"
      continue
    fi
    ACTUAL_MARKER="$MARKER"
    echo "  add: ok (integration)"
  else
    ADD_LOG="$LOGDIR/cycle_${i}_add.log"
    if ! launch_with_marker "$MARKER" >"$ADD_LOG" 2>&1; then
      echo "FAIL cycle $i: launch (add)"
      tail -5 "$ADD_LOG" || true
      continue
    fi
    sleep "$LAUNCH_WAIT"

    PREFS_ADD="$LOGDIR/cycle_${i}_add.plist"
    if ! pull_prefs "$PREFS_ADD"; then
      echo "FAIL cycle $i: prefs pull (add)"
      continue
    fi
    ACTUAL_MARKER=$(extract_latest_task_marker "$PREFS_ADD")
    if [[ -z "$ACTUAL_MARKER" ]] || ! marker_in_prefs "$PREFS_ADD" "$ACTUAL_MARKER"; then
      echo "FAIL cycle $i: marker not in SP after add (size=$(wc -c <"$PREFS_ADD" | tr -d ' '))"
      continue
    fi
    echo "  add: SP ok marker=$ACTUAL_MARKER"
  fi

  stop_app
  sleep 3

  LAUNCH_LOG="$LOGDIR/cycle_${i}_launch.log"
  if ! launch_with_marker "$ACTUAL_MARKER" >"$LAUNCH_LOG" 2>&1; then
    echo "FAIL cycle $i: cold launch"
    tail -5 "$LAUNCH_LOG" || true
    continue
  fi
  sleep "$LAUNCH_WAIT"

  PREFS="$LOGDIR/cycle_${i}_launch.plist"
  if ! pull_prefs "$PREFS"; then
    echo "FAIL cycle $i: prefs pull (launch)"
    continue
  fi

  if marker_in_prefs "$PREFS" "$ACTUAL_MARKER"; then
    echo "  cold launch: restore ok"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "FAIL cycle $i: marker missing after cold launch (size=$(wc -c <"$PREFS" | tr -d ' '))"
  fi

  stop_app
  sleep 1
done

echo ""
echo "=== RESULT: $SUCCESS / $CYCLES ==="
echo "[FlowDoPersistResult] device_success=$SUCCESS/$CYCLES" | tee "$LOGDIR/summary.txt"
[[ "$SUCCESS" -eq "$CYCLES" ]]
