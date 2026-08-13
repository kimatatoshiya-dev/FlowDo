import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/home_dashboard.dart';

import 'home_dashboard_test.dart' show sampleTasks;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase1-1 今日・7日以内サマリーカード', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
          body: HomeDashboard(
            tasks: sampleTasks(),
            today: DateTime(2026, 8, 11),
            categoryCounts: const [],
            onCalendarDayTap: (_, __) {},
            onOpenTodayFocusSheet: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('dashboard_summary_row')),
      matchesGoldenFile('goldens/dashboard_phase1_1_summary.png'),
    );
  });
}
