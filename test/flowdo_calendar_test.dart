import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/flowdo_calendar.dart';
import 'package:flowdo/models/task.dart';

void main() {
  final today = DateTime(2026, 8, 11);

  Task task({
    required int id,
    required String title,
    bool isFavorite = false,
    DateTime? dueDate,
    bool isCompleted = false,
  }) {
    return Task(
      id: id,
      title: title,
      isInbox: false,
      isFavorite: isFavorite,
      dueDate: dueDate,
      isCompleted: isCompleted,
    );
  }

  group('buildFlowDoCalendarMonth', () {
    test('サマリー件数を集計する', () {
      final data = buildFlowDoCalendarMonth(
        tasks: [
          task(id: 1, title: 'a', isFavorite: true),
          task(id: 2, title: 'b', dueDate: today),
          task(id: 3, title: 'c', dueDate: DateTime(2026, 8, 20)),
          task(id: 4, title: 'd', dueDate: DateTime(2026, 9, 1)),
        ],
        today: today,
      );

      expect(data.summary.importantCount, 1);
      expect(data.summary.dueTodayCount, 1);
      expect(data.summary.dueThisMonthCount, 2);
    });

    test('日付セルにマーカーを付ける', () {
      final data = buildFlowDoCalendarMonth(
        tasks: [
          task(id: 1, title: 'important today', isFavorite: true),
          task(id: 2, title: 'due today', dueDate: today),
          task(id: 3, title: 'scheduled', dueDate: DateTime(2026, 8, 20)),
        ],
        today: today,
      );

      final todayMarkers = data.markersFor(today);
      expect(todayMarkers.showImportant, isTrue);
      expect(todayMarkers.showDueToday, isTrue);
      expect(todayMarkers.showScheduled, isTrue);

      final scheduledMarkers = data.markersFor(DateTime(2026, 8, 20));
      expect(scheduledMarkers.showScheduled, isTrue);
      expect(scheduledMarkers.showDueToday, isFalse);
    });
  });

  group('calendarTasksForDay', () {
    test('指定日のタスクを種別付きで返す', () {
      final entries = calendarTasksForDay(
        tasks: [
          task(id: 1, title: 'important today', isFavorite: true),
          task(id: 2, title: 'due today', dueDate: today),
          task(id: 3, title: 'scheduled', dueDate: DateTime(2026, 8, 20)),
        ],
        day: today,
        today: today,
      );

      expect(entries, hasLength(2));
      expect(entries[0].kind, FlowDoCalendarTaskKind.important);
      expect(entries[1].kind, FlowDoCalendarTaskKind.dueToday);
    });
  });

  test('formatCalendarDayTitle は日本語の曜日を返す', () {
    expect(formatCalendarDayTitle(DateTime(2026, 8, 11)), '8月11日（火）');
  });
}
