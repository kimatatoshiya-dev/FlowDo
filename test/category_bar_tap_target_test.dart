import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/widgets/category_bar.dart';

void main() {
  testWidgets('グループチップの HitTest 領域が 46pt 以上', (WidgetTester tester) async {
    const categories = [
      CategoryItem(
        id: CategoryItem.uncategorizedId,
        name: '未分類',
        colorValue: 0xFF8E8E93,
        isSystem: true,
      ),
      CategoryItem(id: 'work', name: '仕事', colorValue: 0xFF007AFF),
    ];

    String? selectedId = 'work';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CategoryBar(
                categories: categories,
                selectedIds: selectedId == null ? {} : {selectedId!},
                addButtonKey: const ValueKey('category_add_chip'),
                onSelected: (id) => setState(() => selectedId = id),
                onAdd: (_) {},
                onRename: (_) {},
                onDelete: (_) {},
              );
            },
          ),
        ),
      ),
    );

    const tapTargetKeys = [
      ValueKey('category_chip_tap_all'),
      ValueKey('category_chip_tap_work'),
      ValueKey('category_add_chip'),
    ];

    for (final key in tapTargetKeys) {
      final finder = find.byKey(key);
      expect(finder, findsOneWidget);

      final size = tester.getSize(finder);
      expect(
        size.height,
        greaterThanOrEqualTo(kCategoryChipTapHeight),
        reason: '$key height=${size.height}',
      );
    }

    // チップ見た目より上下の余白部分でもタップが効くこと
    final allChipFinder = find.byKey(const ValueKey('category_chip_tap_all'));
    final allChipRect = tester.getRect(allChipFinder);
    final visualChipFinder = find.descendant(
      of: allChipFinder,
      matching: find.text('すべて'),
    );
    final visualRect = tester.getRect(visualChipFinder);
    expect(allChipRect.height, greaterThan(visualRect.height));

    await tester.tapAt(
      Offset(allChipRect.center.dx, allChipRect.top + 1),
    );
    await tester.pumpAndSettle();

    expect(selectedId, isNull);
  });

  testWidgets('iOS で横スクロールに BouncingScrollPhysics が使われる',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryBar(
              categories: CategoryItem.defaults(),
              selectedIds: const {},
              onSelected: (_) {},
              onAdd: (_) {},
              onRename: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      final scrollConfiguration = tester.widget<ScrollConfiguration>(
        find.descendant(
          of: find.byType(CategoryBar),
          matching: find.byType(ScrollConfiguration),
        ),
      );
      final physics = scrollConfiguration.behavior!.getScrollPhysics(
        tester.element(find.byType(CategoryBar)),
      );
      expect(physics, isA<BouncingScrollPhysics>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('カテゴリー選択時に AnimatedScale が反応する',
      (WidgetTester tester) async {
    const categories = [
      CategoryItem(
        id: CategoryItem.uncategorizedId,
        name: '未分類',
        colorValue: 0xFF8E8E93,
        isSystem: true,
      ),
      CategoryItem(id: 'work', name: '仕事', colorValue: 0xFF007AFF),
    ];

    String? selectedId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CategoryBar(
                categories: categories,
                selectedIds: selectedId == null ? {} : {selectedId!},
                onSelected: (id) => setState(() => selectedId = id),
                onAdd: (_) {},
                onRename: (_) {},
                onDelete: (_) {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedScale), findsWidgets);

    await tester.tap(find.text('仕事'));
    await tester.pump();
    await tester.pump(kCategoryChipSelectionDuration);

    final workScale = tester.widget<AnimatedScale>(
      find
          .descendant(
            of: find.byKey(const ValueKey('category_chip_tap_work')),
            matching: find.byType(AnimatedScale),
          )
          .first,
    );
    expect(workScale.scale, kCategoryChipSelectedScale);
  });

  testWidgets('選択中カテゴリーは solid ● マーカーで視認できる',
      (WidgetTester tester) async {
    const categories = [
      CategoryItem(
        id: CategoryItem.uncategorizedId,
        name: '未分類',
        colorValue: 0xFF8E8E93,
        isSystem: true,
      ),
      CategoryItem(id: 'work', name: '仕事', colorValue: 0xFF007AFF),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryBar(
            categories: categories,
            selectedIds: const {'work'},
            onSelected: (_) {},
            onAdd: (_) {},
            onRename: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    final workChip = find.byKey(const ValueKey('category_chip_tap_work'));
    expect(
      find.descendant(
        of: workChip,
        matching: find.byKey(const ValueKey('category_marker_selected')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: workChip,
        matching: find.byKey(const ValueKey('category_marker_unselected')),
      ),
      findsNothing,
    );

    final allChip = find.byKey(const ValueKey('category_chip_tap_all'));
    expect(
      find.descendant(
        of: allChip,
        matching: find.byKey(const ValueKey('category_marker_selected')),
      ),
      findsNothing,
    );
  });
}
