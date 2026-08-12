import 'package:flutter/material.dart';
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
    TimeOfDay? reminderTime,
    bool isCompleted = false,
  }) {
    return Task(
      id: id,
      title: title,
      isInbox: false,
      isFavorite: isFavorite,
      dueDate: dueDate,
      reminderTime: reminderTime,
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

    test('表示月を指定するとその月のタスクマーカーを返す', () {
      final data = buildFlowDoCalendarMonth(
        tasks: [
          task(id: 1, title: 'september', dueDate: DateTime(2026, 9, 15)),
          task(id: 2, title: 'august', dueDate: DateTime(2026, 8, 20)),
        ],
        month: DateTime(2026, 9, 1),
        today: today,
      );

      expect(data.summary.dueThisMonthCount, 1);
      expect(data.markersFor(DateTime(2026, 9, 15)).showScheduled, isTrue);
      expect(data.markersFor(DateTime(2026, 8, 20)).hasAny, isFalse);
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

    test('時間付きタスクを時間順に並べ、時間なしは後ろ', () {
      final entries = calendarTasksForDay(
        tasks: [
          task(
            id: 1,
            title: 'メール返信',
            dueDate: today,
            reminderTime: null,
          ),
          task(
            id: 2,
            title: '提案書',
            dueDate: today,
            reminderTime: const TimeOfDay(hour: 10, minute: 30),
          ),
          task(
            id: 3,
            title: '会議',
            dueDate: today,
            reminderTime: const TimeOfDay(hour: 9, minute: 0),
          ),
        ],
        day: today,
        today: today,
      );

      expect(entries.map((entry) => entry.title).toList(), [
        '会議',
        '提案書',
        'メール返信',
      ]);
    });
  });

  test('formatCalendarDayTitle は日本語の曜日を返す', () {
    expect(formatCalendarDayTitle(DateTime(2026, 8, 11)), '8月11日（火）');
  });
}
