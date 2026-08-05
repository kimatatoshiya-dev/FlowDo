#!/bin/sh
# Personal Team macOS builds cannot use Sign in with Apple.
# Google Sign-In only on macOS; strip any generated Apple Sign-In native config.
set -eu

MACOS_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

for ENT in \
  "$MACOS_ROOT/Runner/DebugProfile.entitlements" \
  "$MACOS_ROOT/Runner/Release.entitlements"
do
  if [ -f "$ENT" ]; then
    /usr/bin/plutil -remove com.apple.developer.applesignin "$ENT" 2>/dev/null || true
  fi
done

REGISTRANT="$MACOS_ROOT/Flutter/GeneratedPluginRegistrant.swift"
if [ -f "$REGISTRANT" ]; then
  grep -v 'sign_in_with_apple' "$REGISTRANT" | grep -v 'SignInWithApplePlugin' > "${REGISTRANT}.tmp"
  mv "${REGISTRANT}.tmp" "$REGISTRANT"
fi

PACKAGE_SWIFT="$MACOS_ROOT/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
if [ -f "$PACKAGE_SWIFT" ]; then
  grep -v 'sign_in_with_apple' "$PACKAGE_SWIFT" | grep -v 'sign-in-with-apple' > "${PACKAGE_SWIFT}.tmp"
  mv "${PACKAGE_SWIFT}.tmp" "$PACKAGE_SWIFT"
fi
