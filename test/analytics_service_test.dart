import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/services/analytics/analytics_service.dart';

void main() {
  group('NoOpAnalyticsService', () {
    const service = NoOpAnalyticsService();

    test('イベント送信は例外を投げない', () async {
      await expectLater(service.logAppOpen(), completes);
      await expectLater(
        service.logScreenView(AnalyticsScreen.home),
        completes,
      );
      await expectLater(service.logFirstLaunch(), completes);
      await expectLater(
        service.logSessionDuration(durationSeconds: 120),
        completes,
      );
      await expectLater(service.logCaptureUsed(taskCount: 1), completes);
      await expectLater(service.logBulkInputCount(count: 3), completes);
      await expectLater(service.logTaskCreated(taskCount: 2), completes);
      await expectLater(service.logTaskCompleted(), completes);
      await expectLater(service.logTaskDeleted(), completes);
      await expectLater(
        service.logCategoryChanged(context: AnalyticsContext.inbox),
        completes,
      );
      await expectLater(
        service.logPriorityChanged(
          context: AnalyticsContext.list,
          stars: 3,
        ),
        completes,
      );
      await expectLater(service.logDeadlineSet(daysUntilDue: 7), completes);
      await expectLater(service.logAiSortStarted(taskCount: 3), completes);
      await expectLater(service.logAiSortCompleted(taskCount: 3), completes);
      await expectLater(service.logSoundEnabled(), completes);
      await expectLater(service.logSoundDisabled(), completes);
      await expectLater(service.logHapticEnabled(), completes);
      await expectLater(service.logHapticDisabled(), completes);
      await expectLater(
        service.logThemeChanged(ThemeMode.dark),
        completes,
      );
    });
  });
}
