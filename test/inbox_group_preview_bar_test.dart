import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/widgets/category_bar.dart';
import 'package:flowdo/widgets/inbox_group_preview_bar.dart';

void main() {
  testWidgets('整理待ちグループバーは ReorderableListView を表示する',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InboxGroupPreviewBar(
            categories: const [
              CategoryItem(
                id: CategoryItem.uncategorizedId,
                name: '未分類',
                colorValue: 0xFF8E8E93,
                isSystem: true,
                displayOrder: 0,
              ),
              CategoryItem(
                id: 'work',
                name: '仕事',
                colorValue: 0xFF007AFF,
                displayOrder: 1,
              ),
            ],
            onAdd: (_) {},
            onRename: (_) {},
            onDelete: (_) {},
            onReorder: (_, __) {},
          ),
        ),
      ),
    );

    expect(find.byType(HorizontalReorderableChipRow), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox_category_chip_work')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox_category_add_chip')), findsOneWidget);
  });
}
