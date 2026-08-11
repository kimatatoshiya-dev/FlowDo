import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/config/app_features.dart';
import 'package:flowdo/main.dart';
import 'package:flowdo/services/analytics/noop_analytics_service.dart';
import 'package:flowdo/services/auth/noop_auth_service.dart';
import 'package:flowdo/services/tasks/local_task_repository.dart';

const flowDoTestAnalyticsService = NoOpAnalyticsService();
const flowDoTestAuthService = NoOpAuthService();

/// 登録フィードバック等の短い遅延を消化する待機時間
const flowDoRegistrationSettleDuration = Duration(milliseconds: 600);

/// Inbox 整理（リストへ移動）の待機時間
const flowDoInboxPromoteDelayDuration = Duration(milliseconds: 2500);

/// テスト用に FlowDoApp を起動し、初期ロード完了まで待つ。
Future<void> pumpFlowDoApp(
  WidgetTester tester, {
  Map<String, Object> initialPreferences = const {},
}) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(initialPreferences);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  await tester.pumpWidget(
    FlowDoApp(
      analyticsService: flowDoTestAnalyticsService,
      authService: flowDoTestAuthService,
      taskRepository: LocalTaskRepository(),
    ),
  );

  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// 操作後に UI を落ち着かせる（pumpAndSettle はセッション計測タイマーで止まるため使わない）
Future<void> settleFlowDoUi(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
}

/// ダイアログ閉鎖後の runAfterDialogClosed 完了まで待つ
Future<void> settleAfterDialogClosed(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// タスク登録後のフィードバックタイマーを消化する
Future<void> settleAfterTaskRegistration(WidgetTester tester) async {
  await tester.pump(flowDoRegistrationSettleDuration);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Inbox 整理の待機アニメーション完了まで進める
Future<void> settleInboxPromoteDelay(WidgetTester tester) async {
  await tester.pump(flowDoInboxPromoteDelayDuration);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await settleFlowDoUi(tester);
}

/// テスト終了前に残りタイマーを消化する
Future<void> drainFlowDoTimers(WidgetTester tester) async {
  await tester.pump(flowDoRegistrationSettleDuration);
  await tester.pump(flowDoInboxPromoteDelayDuration);
}

/// 無料版では AI 整理ボタンが非表示であることを検証する。
void expectAiOrganizeButtonHidden() {
  expect(find.text('✨ AIで整理する'), findsNothing);
}

/// 無料版では手動の「整理する」ボタンが表示されることを検証する。
void expectManualOrganizeButtonVisible() {
  expect(find.text('整理する'), findsOneWidget);
}

/// 有料版向け: AI 整理ボタンの Finder。
Finder get organizeButtonFinder {
  assert(
    kAiOrganizeEnabled,
    'organizeButtonFinder is only valid when kAiOrganizeEnabled is true',
  );
  return find.text('✨ AIで整理する');
}
