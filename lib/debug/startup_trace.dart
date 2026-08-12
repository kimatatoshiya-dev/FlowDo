import 'package:flutter/foundation.dart';

/// Debug ビルドのみの起動トレース。
void startupTrace(String step, [Object? detail]) {
  if (!kDebugMode) return;
  debugPrint('[FlowDoStartup] $step${detail == null ? '' : ': $detail'}');
}

/// 起動調査用: debug/release 問わず必ず出力する。
void startupProbe(String step, [Object? detail]) {
  debugPrint(
    '[FlowDoStartupProbe] $step${detail == null ? '' : ': $detail'}',
  );
}
