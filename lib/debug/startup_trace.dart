import 'package:flutter/foundation.dart';

/// Debug ビルドのみの起動トレース。
void startupTrace(String step, [Object? detail]) {
  if (!kDebugMode) return;
  debugPrint('[FlowDoStartup] $step${detail == null ? '' : ': $detail'}');
}
