import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/services/crash_reporting.dart';

void main() {
  test('Debug ビルドでは Crashlytics 送信を無効化する', () {
    expect(isCrashReportingEnabled, isFalse);
    expect(kReleaseMode, isFalse);
  });

  test('reportZonedError は Debug でも例外を投げない', () {
    expect(
      () => reportZonedError(Exception('test'), StackTrace.current),
      returnsNormally,
    );
  });

  test('recordHandledError は Debug でも例外を投げない', () async {
    await expectLater(
      recordHandledError(
        Exception('test'),
        StackTrace.current,
        reason: 'test',
        fatal: false,
      ),
      completes,
    );
  });

  test('Crashlytics テスト API は Debug でも例外を投げない', () async {
    await expectLater(testCrashlyticsNonFatal(), completes);
    await expectLater(testCrashlyticsFlutterFatal(), completes);
    await expectLater(testCrashlyticsAsyncNonFatal(), completes);
    expect(
      () => testCrashlyticsNativeFatal(),
      throwsA(isA<StateError>()),
    );
  });
}
