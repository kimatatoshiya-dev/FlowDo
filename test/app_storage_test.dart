import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/completed_task_retention.dart';
import 'package:flowdo/services/app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  test('warmUp succeeds with mock SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final ready = await AppStorage.warmUp();
    expect(ready, isTrue);
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
}
