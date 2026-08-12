import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/config/app_features.dart';
import 'package:flowdo/app_bootstrap.dart';
import 'package:flowdo/services/app_storage.dart';
import 'package:flowdo/services/analytics/noop_analytics_service.dart';
import 'package:flowdo/services/auth/noop_auth_service.dart';
import 'package:flowdo/services/tasks/local_task_repository.dart';
import 'package:flowdo/services/crash_reporting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetForTesting();
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    AppStorage.resetForTesting();
  });

  test('無料版 v1 では Firebase / クラウド認証を使わない', () async {
    expect(kFirebaseEnabled, isFalse);
    expect(kCloudAuthEnabled, isFalse);
    expect(kGuestModeEnabled, isTrue);

    final bootstrap = await bootstrapApp();

    expect(bootstrap.analyticsService, isA<NoOpAnalyticsService>());
    expect(bootstrap.authService, isA<NoOpAuthService>());
    expect(bootstrap.taskRepository, isA<LocalTaskRepository>());
  });

  test('Debug ビルドでは Crashlytics のみ無効', () {
    expect(kReleaseMode, isFalse);
    expect(isCrashReportingEnabled, isFalse);
  });
}
