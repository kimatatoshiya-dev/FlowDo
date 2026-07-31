import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/main.dart';
import 'package:flowdo/services/analytics/noop_analytics_service.dart';
import 'package:flowdo/services/auth/noop_auth_service.dart';

Future<void> _pumpFlowDo(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  testWidgets('最近追加タスクをタップすると編集シートが開く', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService()));
    await _pumpFlowDo(tester);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '編集対象',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('編集対象', skipOffstage: false));
    await tester.tap(find.text('編集対象', skipOffstage: false));
    await tester.pumpAndSettle();

    expect(find.text('タスクを編集'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('編集シートで名前を保存できる', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService()));
    await _pumpFlowDo(tester);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '旧タイトル',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('旧タイトル', skipOffstage: false));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '新タイトル');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('新タイトル', skipOffstage: false), findsOneWidget);
    expect(find.text('旧タイトル', skipOffstage: false), findsNothing);
  });
}
