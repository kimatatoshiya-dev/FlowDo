import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/dashboard_weather_snapshot.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/dashboard/dashboard_weather_card.dart';

void main() {
  testWidgets('DashboardWeatherCard は通常の天気を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: DashboardWeatherCard(
            weather: DashboardWeatherSnapshot(
              locationLabel: '東京',
              temperatureCelsius: 31,
              precipitationPercent: 20,
              weatherIconEmoji: '☀️',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('dashboard_weather_card')), findsOneWidget);
    expect(find.text('31℃'), findsOneWidget);
    expect(find.text('東京'), findsOneWidget);
    expect(find.text('降水確率 20%'), findsOneWidget);
    expect(find.text('☀️'), findsOneWidget);
  });

  testWidgets('DashboardWeatherCard は取得失敗メッセージを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: DashboardWeatherCard(
            weather: DashboardWeatherSnapshot.unavailable,
          ),
        ),
      ),
    );

    expect(find.text('天気を取得できませんでした'), findsOneWidget);
    expect(find.text('--℃'), findsOneWidget);
    expect(find.textContaining('降水確率'), findsNothing);
  });
}
