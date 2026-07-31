import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'analytics/analytics_service.dart';

/// Crashlytics は Release ビルドのみ Firebase へ送信する
bool get isCrashReportingEnabled => kReleaseMode;

/// @Deprecated 互換のため残す
bool get isMonitoringEnabled => isCrashReportingEnabled;

/// Firebase 初期化・Crashlytics・Analytics をセットアップする
Future<AnalyticsService> initializeAppMonitoring() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stack) {
    debugPrint('Firebase initialization failed: $error');
    debugPrint(stack.toString());
    _installDebugErrorHandlers();
    return const NoOpAnalyticsService();
  }

  try {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    await _initializeCrashlytics();

    return FirebaseAnalyticsService(FirebaseAnalytics.instance);
  } catch (error, stack) {
    debugPrint('App monitoring initialization failed: $error');
    debugPrint(stack.toString());
    _installDebugErrorHandlers();
    return const NoOpAnalyticsService();
  }
}

Future<void> _initializeCrashlytics() async {
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    isCrashReportingEnabled,
  );

  if (isCrashReportingEnabled) {
    _installCrashReportingHandlers();
    _installGracefulErrorWidget();
  } else {
    _installDebugErrorHandlers();
  }
}

/// runZonedGuarded から呼び出す（Non-Fatal）
void reportZonedError(Object error, StackTrace stack) {
  if (isCrashReportingEnabled) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: false,
        reason: 'uncaught_zone_error',
      ),
    );
  }

  debugPrint('Uncaught zone error: $error');
  debugPrint(stack.toString());
}

/// 任意の catch ブロックから記録する（Fatal / Non-Fatal 指定可）
Future<void> recordHandledError(
  Object error,
  StackTrace stack, {
  String? reason,
  bool fatal = false,
}) async {
  debugPrint('Handled error${reason == null ? '' : ' ($reason)'}: $error');
  debugPrint(stack.toString());

  if (!isCrashReportingEnabled) return;

  await FirebaseCrashlytics.instance.recordError(
    error,
    stack,
    reason: reason,
    fatal: fatal,
  );
}

/// Debug メニュー: Non-Fatal エラー送信テスト
Future<String> testCrashlyticsNonFatal() async {
  await recordHandledError(
    Exception('FlowDo Crashlytics non-fatal test'),
    StackTrace.current,
    reason: 'crash_test_non_fatal',
    fatal: false,
  );

  if (isCrashReportingEnabled) {
    return 'Non-Fatal エラーを Crashlytics に送信しました。数分後に Console を確認してください。';
  }
  return 'Debug ビルドのため Crashlytics には送信されません。Release ビルドで確認してください。';
}

/// Debug メニュー: Flutter フレームワーク Fatal エラー送信テスト
Future<String> testCrashlyticsFlutterFatal() async {
  if (!isCrashReportingEnabled) {
    return 'Debug ビルドのため Crashlytics には送信されません。Release ビルドで確認してください。';
  }

  final details = FlutterErrorDetails(
    exception: Exception('FlowDo Crashlytics flutter fatal test'),
    stack: StackTrace.current,
    library: 'crash_test',
    context: ErrorDescription('Debug menu crash test'),
  );

  await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  return 'Flutter Fatal エラーを Crashlytics に送信しました。Console を確認してください。';
}

/// Debug メニュー: 非同期 Non-Fatal エラー（Zone 経由）送信テスト
Future<String> testCrashlyticsAsyncNonFatal() async {
  scheduleMicrotask(() {
    reportZonedError(
      Exception('FlowDo Crashlytics async non-fatal test'),
      StackTrace.current,
    );
  });

  if (isCrashReportingEnabled) {
    return 'Async Non-Fatal エラーを Crashlytics に送信しました。Console を確認してください。';
  }
  return 'Debug ビルドのため Crashlytics には送信されません。Release ビルドで確認してください。';
}

/// Debug メニュー: ネイティブ Fatal クラッシュ（アプリが終了します）
void testCrashlyticsNativeFatal() {
  if (!isCrashReportingEnabled) {
    throw StateError('Native Fatal テストは Release ビルドでのみ実行できます。');
  }
  FirebaseCrashlytics.instance.crash();
}

void _installCrashReportingHandlers() {
  FlutterError.onError = (details) {
    unawaited(_sendFlutterErrorToCrashlytics(details));
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: true,
        reason: 'uncaught_async_error',
      ),
    );
    debugPrint('Uncaught async error: $error');
    debugPrint(stack.toString());
    return true;
  };
}

Future<void> _sendFlutterErrorToCrashlytics(FlutterErrorDetails details) async {
  if (!isCrashReportingEnabled) return;

  if (details.silent) {
    await FirebaseCrashlytics.instance.recordFlutterError(
      details,
      fatal: false,
    );
    return;
  }

  await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
}

void _installDebugErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error');
    debugPrint(stack.toString());
    return true;
  };
}

void _installGracefulErrorWidget() {
  ErrorWidget.builder = (details) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '表示できませんでした。\n操作を続けてください。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  };
}
