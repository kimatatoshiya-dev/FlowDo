import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/task_swipe_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSwipe({
    required VoidCallback onComplete,
    required VoidCallback onEdit,
    required VoidCallback onDismissDelete,
    required Future<bool> Function() confirmDelete,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 390,
          child: TaskSwipeActions(
            key: const ValueKey('swipe_demo'),
            onComplete: onComplete,
            onEdit: onEdit,
            onDismissDelete: onDismissDelete,
            confirmDelete: confirmDelete,
            child: Container(
              height: 72,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white,
              child: const Text('スワイプ確認タスク'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('右スワイプで完了コールバックが呼ばれる', (tester) async {
    var completed = false;

    await tester.pumpWidget(
      buildSwipe(
        onComplete: () => completed = true,
        onEdit: () {},
        onDismissDelete: () {},
        confirmDelete: () async => false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('swipe_demo')),
      const Offset(180, 0),
    );
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('左スワイプで編集コールバックが呼ばれる', (tester) async {
    var edited = false;

    await tester.pumpWidget(
      buildSwipe(
        onComplete: () {},
        onEdit: () => edited = true,
        onDismissDelete: () {},
        confirmDelete: () async => false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('swipe_demo')),
      const Offset(-140, 0),
    );
    await tester.pumpAndSettle();

    expect(edited, isTrue);
  });

  testWidgets('深い左スワイプで削除確認後に削除コールバックが呼ばれる', (tester) async {
    var deleted = false;

    await tester.pumpWidget(
      buildSwipe(
        onComplete: () {},
        onEdit: () {},
        onDismissDelete: () => deleted = true,
        confirmDelete: () async => true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('swipe_demo')),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}
