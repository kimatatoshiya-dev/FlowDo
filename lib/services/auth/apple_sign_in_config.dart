import 'dart:io';

import 'package:flutter/foundation.dart';

/// Sign in with Apple を有効にするかどうか。
///
/// Personal Team では Debug / Profile ビルド用に
/// [ios/Runner/Runner-Debug.entitlements]（Apple Sign In なし）を使う。
/// Release ビルドのみ [ios/Runner/Runner.entitlements] を参照する。
bool get isAppleSignInEnabledForBuild {
  if (!Platform.isIOS) return false;
  return kReleaseMode;
}
