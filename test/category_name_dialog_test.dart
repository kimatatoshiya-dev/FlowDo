import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/widgets/category_name_dialog.dart';

void main() {
  testWidgets('カテゴリー追加ダイアログを連続で開いても GlobalKey エラーにならない',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showCategoryNameDialog(
                  context,
                  title: 'カテゴリー追加',
                  confirmLabel: '追加',
                ),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'カテゴリー$i');
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();
    }

    expect(find.text('GlobalKey'), findsNothing);
  });

  testWidgets('showDialog を開き直してもエラーにならない', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showCategoryNameDialog(
                  context,
                  title: 'カテゴリー追加',
                  confirmLabel: '追加',
                ),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });
}
