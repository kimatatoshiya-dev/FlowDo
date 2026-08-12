import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/main.dart';
import 'package:flowdo/models/completed_task_retention.dart';
import 'package:flowdo/models/feedback_preferences.dart';
import 'package:flowdo/models/notification_preferences.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/analytics/noop_analytics_service.dart';
import 'package:flowdo/services/auth/noop_auth_service.dart';
import 'package:flowdo/services/feedback_service.dart';
import 'package:flowdo/services/task_notification_service.dart';
import 'package:flowdo/services/tasks/task_repository.dart';
import 'package:flowdo/theme/app_theme.dart';

/// watchTasks() の subscribe / cancel を追跡するテスト用リポジトリ
class SubscriptionTrackingTaskRepository implements TaskRepository {
  SubscriptionTrackingTaskRepository();

  final StreamController<List<Task>> _controller =
      StreamController<List<Task>>.broadcast();

  int watchTasksCallCount = 0;
  bool get hasActiveListener => _controller.hasListener;

  @override
  Stream<List<Task>> watchTasks() async* {
    watchTasksCallCount++;
    yield const [];
    yield* _controller.stream;
  }

  @override
  Future<List<Task>> loadTasks() async => const [];

  @override
  Future<void> createTask(Task task) async {}

  @override
  Future<void> updateTask(Task task) async {}

  @override
  Future<void> deleteTask(int taskId) async {}

  @override
  Future<void> syncTasks(List<Task> tasks) async {}

  Future<void> dispose() async {
    await _controller.close();
  }
}

Widget _homePage({
  required TaskRepository taskRepository,
  Key key = const ValueKey('flowdo_home_test'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: FlowDoHomePage(
      key: key,
      themeMode: ThemeMode.system,
      onThemeModeChanged: (_) {},
      feedbackService: NoOpFeedbackService(),
      feedbackPreferences: FeedbackPreferences.defaults,
      onFeedbackPreferencesChanged: (_) {},
      taskNotificationService: NoOpTaskNotificationService(),
      notificationPreferences: NotificationPreferences.defaults,
      onNotificationPreferencesChanged: (_) {},
      completedTaskRetention: CompletedTaskRetention.defaults,
      onCompletedTaskRetentionChanged: (_) {},
      analyticsService: const NoOpAnalyticsService(),
      authService: const NoOpAuthService(),
      taskRepository: taskRepository,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initState で watchTasks が 1 回だけ bind される', (tester) async {
    final repository = SubscriptionTrackingTaskRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(_homePage(taskRepository: repository));
    await tester.pump();

    expect(repository.watchTasksCallCount, 1);
    expect(repository.hasActiveListener, isTrue);

    // 同じ State を維持したまま rebuild しても再 bind しない
    await tester.pumpWidget(_homePage(taskRepository: repository));
    await tester.pump();

    expect(repository.watchTasksCallCount, 1);
    expect(repository.hasActiveListener, isTrue);
  });

  testWidgets('dispose で StreamSubscription が cancel される', (tester) async {
    final repository = SubscriptionTrackingTaskRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(_homePage(taskRepository: repository));
    await tester.pump();
    expect(repository.hasActiveListener, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.hasActiveListener, isFalse);
    expect(find.byType(FlowDoHomePage), findsNothing);
  });

  testWidgets('taskRepository 変更時は旧 subscription を cancel して 1 本だけ張り直す',
      (tester) async {
    final firstRepository = SubscriptionTrackingTaskRepository();
    final secondRepository = SubscriptionTrackingTaskRepository();
    addTearDown(firstRepository.dispose);
    addTearDown(secondRepository.dispose);

    const homeKey = ValueKey('flowdo_home_test');

    await tester.pumpWidget(
      _homePage(key: homeKey, taskRepository: firstRepository),
    );
    await tester.pump();
    expect(firstRepository.watchTasksCallCount, 1);
    expect(firstRepository.hasActiveListener, isTrue);

    await tester.pumpWidget(
      _homePage(key: homeKey, taskRepository: secondRepository),
    );
    await tester.pump();

    expect(firstRepository.hasActiveListener, isFalse);
    expect(secondRepository.watchTasksCallCount, 1);
    expect(secondRepository.hasActiveListener, isTrue);
  });
}
