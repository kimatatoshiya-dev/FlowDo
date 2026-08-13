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
      expect(data.summary.dueWithin7DaysCount, 1);
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

  group('CalendarDaySheetSummary', () {
    test('表示中エントリから種別件数を集計する', () {
      final summary = CalendarDaySheetSummary.fromEntries(const [
        FlowDoCalendarTaskEntry(
          taskId: 1,
          title: 'a',
          kind: FlowDoCalendarTaskKind.important,
        ),
        FlowDoCalendarTaskEntry(
          taskId: 2,
          title: 'b',
          kind: FlowDoCalendarTaskKind.dueToday,
        ),
        FlowDoCalendarTaskEntry(
          taskId: 3,
          title: 'c',
          kind: FlowDoCalendarTaskKind.scheduled,
        ),
        FlowDoCalendarTaskEntry(
          taskId: 4,
          title: 'd',
          kind: FlowDoCalendarTaskKind.scheduled,
        ),
      ]);

      expect(summary.importantCount, 1);
      expect(summary.dueTodayCount, 1);
      expect(summary.scheduledCount, 2);
      expect(summary.hasAny, isTrue);
    });
  });

  group('calendarTasksForDay', () {
    test('8/13 には重要・今日・予定の各タスクをすべて返す', () {
      final today = DateTime(2026, 8, 13);
      final entries = calendarTasksForDay(
        tasks: [
          task(id: 1, title: 'ゆうと誕プレ', isFavorite: true),
          task(id: 2, title: '今日のタスク', dueDate: today),
          task(
            id: 3,
            title: '7日以内のタスク',
            dueDate: today,
          ),
        ],
        day: today,
        today: today,
      );

      expect(entries, hasLength(3));
      expect(entries.map((entry) => entry.title), [
        'ゆうと誕プレ',
        '7日以内のタスク',
        '今日のタスク',
      ]);
      expect(entries.map((entry) => entry.kind), [
        FlowDoCalendarTaskKind.important,
        FlowDoCalendarTaskKind.dueToday,
        FlowDoCalendarTaskKind.dueToday,
      ]);
    });

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
