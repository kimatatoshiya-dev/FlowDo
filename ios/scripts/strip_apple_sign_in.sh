#!/bin/sh
# Personal Team iOS builds cannot use Sign in with Apple.
# FlowDo v1 keeps kCloudAuthEnabled=false; strip the entitlement for local device runs.
set -eu

IOS_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

for ENT in \
  "$IOS_ROOT/Runner/Runner.entitlements" \
  "$IOS_ROOT/Runner/Runner-Debug.entitlements"
do
  if [ -f "$ENT" ]; then
    /usr/bin/plutil -remove com.apple.developer.applesignin "$ENT" 2>/dev/null || true
  fi
done
