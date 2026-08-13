import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/task_swipe_actions.dart';
import 'package:flowdo/widgets/task_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSwipeTile(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 358,
              child: TaskTile(
                task: Task(
                  id: 1,
                  title: '買い物リストを作る',
                  isInbox: false,
                  categoryId: 'work',
                  dueDate: DateTime(2026, 8, 13),
                ),
                category: CategoryItem.defaults()[1],
                showCompletedStyle: false,
                isRemoving: false,
                onToggle: () {},
                onEdit: () {},
                onDelete: () {},
                onDismissDelete: () {},
                onCategoryTap: () {},
                onPriorityTap: () {},
                onDueDateTap: () {},
                onFavoriteTap: () {},
                showDivider: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TaskSwipeActionsState swipeState(WidgetTester tester) {
    return tester.state<TaskSwipeActionsState>(find.byKey(const ValueKey(1)));
  }

  testWidgets('Phase1-4 通常状態', (tester) async {
    await pumpSwipeTile(tester);
    await expectLater(
      find.byKey(const ValueKey(1)),
      matchesGoldenFile('goldens/task_swipe_neutral.png'),
    );
  });

  testWidgets('Phase1-4 右スワイプ（完了）', (tester) async {
    await pumpSwipeTile(tester);
    swipeState(tester).debugSetDragOffset(110);
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey(1)),
      matchesGoldenFile('goldens/task_swipe_complete.png'),
    );
  });

  testWidgets('Phase1-4 左スワイプ（編集）', (tester) async {
    await pumpSwipeTile(tester);
    swipeState(tester).debugSetDragOffset(-120);
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey(1)),
      matchesGoldenFile('goldens/task_swipe_edit.png'),
    );
  });

  testWidgets('Phase1-4 深い左スワイプ（削除）', (tester) async {
    await pumpSwipeTile(tester);
    swipeState(tester).debugSetDragOffset(-220);
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey(1)),
      matchesGoldenFile('goldens/task_swipe_delete.png'),
    );
  });
}
