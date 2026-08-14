import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/task_input_bar.dart';
import 'package:flowdo/widgets/today_memo_sheet.dart';

void main() {
  testWidgets('TaskInputBar は今日メモショートカットを表示する',
      (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskInputBar(
            controller: controller,
            onSubmit: () {},
            onTodayMemoTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('today_memo_shortcut')), findsOneWidget);
    expect(find.text('登録'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('today_memo_shortcut')));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('TodayMemoSheet は今日メモセクションを表示する',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayMemoSheet(
            memoText: '振り返りメモ',
            onMemoChanged: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('📝 今日メモ'), findsOneWidget);
    expect(find.text('振り返りメモ'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily_memo_field')), findsOneWidget);
  });
}
