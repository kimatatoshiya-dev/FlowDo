import 'dart:async';

import 'package:flutter/foundation.dart';

/// Code 9 / 無限 rebuild 調査用。debug/release 問わず 1 秒ごとに呼び出し回数を出力する。
const _tag = '[FlowDoHomeLoopDiag]';

class FlowDoHomeLoopDiag {
  FlowDoHomeLoopDiag._();

  static int buildTotal = 0;
  static int applyTotal = 0;
  static int watchEventTotal = 0;
  static int watchTasksEnterTotal = 0;

  static int _buildLastSecond = 0;
  static int _applyLastSecond = 0;
  static int _watchEventLastSecond = 0;
  static int _watchTasksEnterLastSecond = 0;

  static Timer? _reportTimer;
  static bool _started = false;

  /// FlowDoHomePage 初回 initState から 1 秒周期レポートを開始する。
  static void startIfNeeded() {
    if (_started) return;
    _started = true;
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(const Duration(seconds: 1), (_) => _report());
    debugPrint('$_tag started (1s interval)');
  }

  static void stop() {
    _reportTimer?.cancel();
    _reportTimer = null;
    _started = false;
    _report(finalReport: true);
  }

  static void onBuild() => buildTotal++;

  static void onApply() => applyTotal++;

  static void onWatchEvent() => watchEventTotal++;

  static void onWatchTasksEnter() => watchTasksEnterTotal++;

  static void _report({bool finalReport = false}) {
    final buildRate = buildTotal - _buildLastSecond;
    final applyRate = applyTotal - _applyLastSecond;
    final watchEventRate = watchEventTotal - _watchEventLastSecond;
    final watchTasksRate = watchTasksEnterTotal - _watchTasksEnterLastSecond;

    _buildLastSecond = buildTotal;
    _applyLastSecond = applyTotal;
    _watchEventLastSecond = watchEventTotal;
    _watchTasksEnterLastSecond = watchTasksEnterTotal;

    final suffix = finalReport ? ' (final)' : '';
    debugPrint(
      '$_tag$suffix '
      'buildCount=$buildRate/s '
      'applyCount=$applyRate/s '
      'watchEventCount=$watchEventRate/s '
      'watchTasksCount=$watchTasksRate/s '
      '| total build=$buildTotal apply=$applyTotal '
      'watchEvent=$watchEventTotal watchTasks=$watchTasksEnterTotal',
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _reportTimer?.cancel();
    _reportTimer = null;
    _started = false;
    buildTotal = 0;
    applyTotal = 0;
    watchEventTotal = 0;
    watchTasksEnterTotal = 0;
    _buildLastSecond = 0;
    _applyLastSecond = 0;
    _watchEventLastSecond = 0;
    _watchTasksEnterLastSecond = 0;
  }
}
