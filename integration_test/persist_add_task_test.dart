import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flowdo/main.dart' as app;
import 'package:flowdo/services/app_storage.dart';

/// 1サイクル: UI からタスク追加 → SharedPreferences 保存確認（既存データは消さない）
///
/// 実行例:
///   flutter test integration_test/persist_add_task_test.dart \
///     -d 00008150-001529913640C01C \
///     --dart-define=PERSIST_MARKER=phase4-1
Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add task and verify SharedPreferences', (tester) async {
    const marker = String.fromEnvironment(
      'PERSIST_MARKER',
      defaultValue: 'persist-default',
    );

    app.main();
    await tester.pump();

    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const ValueKey('task_input_field')).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(
      find.byKey(const ValueKey('task_input_field')),
      findsOneWidget,
      reason: 'task input not found',
    );

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      marker,
    );
    await tester.tap(find.text('登録'));
    await tester.pump();

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text(marker, skipOffstage: false).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text(marker, skipOffstage: false), findsOneWidget);

    final ready = await AppStorage.ensureReady();
    expect(ready, isTrue);
    final tasks = await AppStorage.loadTasks(
      forceRetry: true,
      diagSource: 'persist_add_task_test',
      logStartupDiag: true,
    );
    expect(
      tasks.any((task) => task.title == marker),
      isTrue,
      reason: 'marker not found in SharedPreferences',
    );

    // ignore: avoid_print
    print('[FlowDoPersistResult] save_ok marker=$marker count=${tasks.length}');
  });
}
