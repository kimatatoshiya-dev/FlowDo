import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/analytics/analytics_service.dart';
import 'services/auth/auth_service.dart';
import 'services/app_storage.dart';
import 'services/crash_reporting.dart';

/// Firebase（Core / Analytics / Crashlytics / Auth）とエラーハンドラを初期化する。
///
/// Analytics は Debug / Release 両方で送信する（DebugView 用）。
/// Crashlytics は Release ビルドのみ送信する。
class AppBootstrapResult {
  const AppBootstrapResult({
    required this.analyticsService,
    required this.authService,
  });

  final AnalyticsService analyticsService;
  final AuthService authService;
}

Future<AppBootstrapResult> bootstrapApp() async {
  final analyticsService = await initializeAppMonitoring();
  final authService = Firebase.apps.isNotEmpty
      ? FirebaseAuthService()
      : const NoOpAuthService(signedIn: false);
  return AppBootstrapResult(
    analyticsService: analyticsService,
    authService: authService,
  );
}

/// SharedPreferences の初期化を待ってから UI データ読み込みを開始する
Future<void> bootstrapAppStorage() async {
  try {
    final ready = await AppStorage.warmUp();
    if (!ready) {
      debugPrint(
        'AppStorage bootstrap: continuing with defaults (persistence disabled)',
      );
    }
  } catch (error, stack) {
    await recordHandledError(error, stack, reason: 'bootstrapAppStorage');
  }
}

/// 初回フレーム描画後に安全に起動処理を実行する
Future<void> runAfterFirstFrame(Future<void> Function() action) async {
  final completer = Completer<void>();

  SchedulerBinding.instance.addPostFrameCallback((_) {
    unawaited(() async {
      try {
        await action();
      } catch (error, stack) {
        await recordHandledError(error, stack, reason: 'runAfterFirstFrame');
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }());
  });

  return completer.future;
}
