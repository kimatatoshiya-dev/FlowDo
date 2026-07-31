import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/app_bootstrap.dart';
import 'package:flowdo/services/analytics/noop_analytics_service.dart';
import 'package:flowdo/services/auth/noop_auth_service.dart';
import 'package:flowdo/services/crash_reporting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Firebase 初期化に失敗した場合は NoOpAnalyticsService を返す', () async {
    expect(kReleaseMode, isFalse);

    final bootstrap = await bootstrapApp();

    expect(bootstrap.analyticsService, isA<NoOpAnalyticsService>());
    expect(bootstrap.authService, isA<NoOpAuthService>());
  });

  test('Debug ビルドでは Crashlytics のみ無効', () {
    expect(kReleaseMode, isFalse);
    expect(isCrashReportingEnabled, isFalse);
  });
}
