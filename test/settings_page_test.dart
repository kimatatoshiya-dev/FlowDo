import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/config/app_links.dart';
import 'package:flowdo/config/app_features.dart';
import 'package:flowdo/models/completed_task_retention.dart';
import 'package:flowdo/models/feedback_preferences.dart';
import 'package:flowdo/models/notification_preferences.dart';
import 'package:flowdo/services/app_version_info.dart';
import 'package:flowdo/services/auth/noop_auth_service.dart';
import 'package:flowdo/screens/about_page.dart';
import 'package:flowdo/screens/settings_page.dart';
import 'package:flowdo/theme/app_theme.dart';

void main() {
  const versionInfo = AppVersionInfo(version: '1.0.0', buildNumber: '1');

  Widget buildSettingsPage() {
    return MaterialApp(
      theme: AppTheme.light(),
      home: SettingsPage(
        themeMode: ThemeMode.system,
        onThemeModeChanged: (_) {},
        feedbackPreferences: FeedbackPreferences.defaults,
        onFeedbackPreferencesChanged: (_) {},
        notificationPreferences: NotificationPreferences.defaults,
        onNotificationPreferencesChanged: (_) {},
        completedTaskRetention: CompletedTaskRetention.defaults,
        onCompletedTaskRetentionChanged: (_) {},
        onDeleteAllCompletedTasks: () async {},
        authService: const NoOpAuthService(),
        onSignInWithGoogle: () async {},
        onSignInWithApple: () async {},
        onSignOut: () async {},
        versionInfo: versionInfo,
      ),
    );
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(buildSettingsPage());
    await tester.scrollUntilVisible(
      find.text('お問い合わせ', skipOffstage: false),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();
  }

  testWidgets('設定画面にアプリ情報とサポート項目を表示する', (WidgetTester tester) async {
    await pumpSettings(tester);

    expect(find.text('設定'), findsOneWidget);
    if (kCloudAuthEnabled) {
      expect(find.text('アカウント', skipOffstage: false), findsOneWidget);
    } else {
      expect(find.text('アカウント', skipOffstage: false), findsNothing);
      expect(find.text('Google でログイン', skipOffstage: false), findsNothing);
    }
    expect(find.text('アプリについて', skipOffstage: false), findsNWidgets(2));
    expect(find.text('バージョン', skipOffstage: false), findsOneWidget);
    expect(find.text('v1.0.0 (1)', skipOffstage: false), findsOneWidget);
    expect(find.text('利用規約', skipOffstage: false), findsOneWidget);
    expect(find.text('プライバシーポリシー', skipOffstage: false), findsOneWidget);
    expect(find.text('お問い合わせ', skipOffstage: false), findsOneWidget);
    expect(find.text(AppLinks.contactEmail, skipOffstage: false), findsOneWidget);
    expect(find.text('通知', skipOffstage: false), findsWidgets);
    expect(find.text('通知タイミング', skipOffstage: false), findsOneWidget);
    expect(find.text('15分前（デフォルト）', skipOffstage: false), findsOneWidget);
  });

  testWidgets('アプリについて画面へ遷移できる', (WidgetTester tester) async {
    await pumpSettings(tester);

    final aboutTile = find.ancestor(
      of: find.text('考えずに入力。行動に集中。'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(aboutTile);
    await tester.tap(aboutTile);
    await tester.pumpAndSettle();

    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('FlowDo'), findsWidgets);
    expect(find.text('v1.0.0 (1)'), findsOneWidget);
  });
}
