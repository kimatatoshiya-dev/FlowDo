import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/completed_task_retention.dart';
import 'package:flowdo/models/notification_preferences.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/app_storage.dart';
import 'package:flowdo/services/tasks/local_task_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SharedPreferences.resetStatic();
    AppStorage.resetForTesting();
  });

  test('ensureReady succeeds with mock SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final ready = await AppStorage.ensureReady();
    expect(ready, isTrue);
    expect(AppStorage.isStorageReady, isTrue);
  });

  test('warmUp delegates to ensureReady', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AppStorage.warmUp(), isTrue);
  });

  test('loadStartupTasks restores saved tasks', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();

    final task = Task.create(title: '起動復元テスト', categoryId: 'work');
    await AppStorage.saveTasks([task]);

    final restored = await AppStorage.loadStartupTasks();
    expect(restored, hasLength(1));
    expect(restored.single.title, '起動復元テスト');
  });

  test('アプリ再起動相当でタスクが復元される', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();

    final beforeRestart = LocalTaskRepository();
    await beforeRestart.createTask(
      Task.create(title: '開発中も残る', categoryId: 'work'),
    );

    final afterRestart = LocalTaskRepository();
    final restored = await afterRestart.loadTasks();

    expect(restored, hasLength(1));
    expect(restored.single.title, '開発中も残る');
  });

  test('loadTasks returns empty list when storage is empty', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();
    final tasks = await AppStorage.loadTasks();
    expect(tasks, isEmpty);
  });

  test('loadThemeMode returns system when storage is empty', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();
    final mode = await AppStorage.loadThemeMode();
    expect(mode, ThemeMode.system);
  });

  test('save and load tasks do not throw', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();

    await expectLater(AppStorage.saveTasks([]), completes);
    await expectLater(AppStorage.loadTasks(), completes);
  });

  test('未保存時は完了タスク保持設定の初期値を返す', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();

    expect(
      await AppStorage.loadCompletedTaskRetention(),
      CompletedTaskRetention.days7,
    );
  });

  test('完了タスク保持設定を保存と読み込みできる', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();

    await AppStorage.saveCompletedTaskRetention(CompletedTaskRetention.days30);

    expect(
      await AppStorage.loadCompletedTaskRetention(),
      CompletedTaskRetention.days30,
    );
  });

  test('未保存時は通知設定の初期値を返す', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();

    expect(
      await AppStorage.loadNotificationPreferences(),
      NotificationPreferences.defaults,
    );
  });

  test('通知設定を保存と読み込みできる', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();

    const preferences = NotificationPreferences(
      enabled: false,
      leadTime: NotificationLeadTime.minutes30,
    );
    await AppStorage.saveNotificationPreferences(preferences);

    expect(
      await AppStorage.loadNotificationPreferences(),
      preferences,
    );
  });

  test('初回起動時のみ通知権限確認フラグを消費する', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();

    expect(await AppStorage.consumeNotificationPermissionPrompt(), isTrue);
    expect(await AppStorage.consumeNotificationPermissionPrompt(), isFalse);
  });
}
