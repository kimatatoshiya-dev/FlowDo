import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'config/app_features.dart';
import 'debug/startup_trace.dart';
import 'services/analytics/analytics_service.dart';
import 'services/auth/auth_service.dart';
import 'services/auth/firebase_auth_service.dart';
import 'services/auth/noop_auth_service.dart';
import 'services/app_storage.dart';
import 'services/crash_reporting.dart';
import 'services/tasks/fallback_task_repository.dart';
import 'services/tasks/firestore_task_repository.dart';
import 'services/tasks/local_task_repository.dart';
import 'services/tasks/task_repository.dart';

/// Firebase（Core / Analytics / Crashlytics / Auth）とエラーハンドラを初期化する。
///
/// [kFirebaseEnabled] が false のときは NoOp のみ。
class AppBootstrapResult {
  const AppBootstrapResult({
    required this.analyticsService,
    required this.authService,
    required this.taskRepository,
  });

  final AnalyticsService analyticsService;
  final AuthService authService;
  final TaskRepository taskRepository;
}

Future<AppBootstrapResult> bootstrapApp() async {
  startupTrace('bootstrapApp() entered');
  startupTrace('initializeAppMonitoring() starting');
  final analyticsService = await initializeAppMonitoring();
  startupTrace('initializeAppMonitoring() done');

  final AuthService authService;
  if (kPaidTierBackendEnabled && Firebase.apps.isNotEmpty) {
    authService = FirebaseAuthService();
    startupTrace('authService created', 'FirebaseAuthService');
  } else {
    authService = const NoOpAuthService(signedIn: false);
    startupTrace('authService created', 'NoOpAuthService');
  }

  startupTrace(
    'authService.currentUser',
    authService.currentUser?.uid ?? 'null',
  );

  if (kPaidTierBackendEnabled) {
    startupTrace('waitForInitialAuthState() starting');
    if (kGuestModeEnabled) {
      unawaited(authService.waitForInitialAuthState());
    } else {
      await authService.waitForInitialAuthState();
    }
    startupTrace(
      'waitForInitialAuthState() scheduled/done',
      authService.currentUser?.uid ?? 'null',
    );
  }

  await bootstrapAppStorage();
  final localTaskRepository = LocalTaskRepository();

  final TaskRepository taskRepository;
  if (kPaidTierBackendEnabled && Firebase.apps.isNotEmpty) {
    taskRepository = AuthAwareTaskRepository(
      firestoreFactory: (userId) => FirestoreTaskRepository(userId: userId),
      local: localTaskRepository,
      authStateChanges: authService.authStateChanges,
      initialUserId: authService.currentUser?.uid,
    );
    startupTrace('taskRepository created', 'AuthAwareTaskRepository');
  } else {
    taskRepository = localTaskRepository;
    startupTrace('taskRepository created', 'LocalTaskRepository');
  }

  startupTrace('bootstrapApp() returning');
  return AppBootstrapResult(
    analyticsService: analyticsService,
    authService: authService,
    taskRepository: taskRepository,
  );
}

/// SharedPreferences の初期化を待ってから UI データ読み込みを開始する
Future<void> bootstrapAppStorage() async {
  startupTrace('bootstrapAppStorage() starting');
  try {
    final ready = await AppStorage.warmUp();
    startupTrace('bootstrapAppStorage() warmUp done', 'ready=$ready');
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
  startupTrace('runAfterFirstFrame() scheduling');
  final completer = Completer<void>();

  SchedulerBinding.instance.addPostFrameCallback((_) {
    startupTrace('runAfterFirstFrame() post-frame callback fired');
    unawaited(() async {
      try {
        await action();
      } catch (error, stack) {
        startupTrace('runAfterFirstFrame() action FAILED', error);
        await recordHandledError(error, stack, reason: 'runAfterFirstFrame');
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
        startupTrace('runAfterFirstFrame() completer done');
      }
    }());
  });

  return completer.future;
}
