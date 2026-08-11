import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/home_dashboard.dart';

void main() {
  testWidgets('1ページ目に今日やることの指標を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            pinnedCount: 2,
            dueTodayCount: 3,
            dueWithin7DaysCount: 5,
            categoryCounts: const [],
          ),
        ),
      ),
    );

    expect(find.text('今日やること'), findsOneWidget);
    expect(find.text('固定'), findsOneWidget);
    expect(find.text('今日期限'), findsOneWidget);
    expect(find.text('7日以内'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(find.text('完了率'), findsNothing);
  });

  testWidgets('2ページ目にカテゴリー別件数を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            pinnedCount: 0,
            dueTodayCount: 0,
            dueWithin7DaysCount: 0,
            categoryCounts: [
              CategoryIncompleteCount(
                category: CategoryItem.defaults()[1],
                count: 18,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('カテゴリー別'), findsOneWidget);
    expect(find.text('仕事'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  test('categoryEmoji はカテゴリー名に応じた絵文字を返す', () {
    expect(categoryEmoji(CategoryItem.defaults()[1]), '📁');
    expect(
      categoryEmoji(CategoryItem.create(name: '買い物', colorValue: 0xFFFF9500)),
      '🛒',
    );
  });
}
