import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/utils/date_formatter.dart';

void main() {
  group('DateFormatter.formatDueDate', () {
    final reference = DateTime(2026, 7, 28);

    test('今年の日付は M/D 形式', () {
      expect(
        DateFormatter.formatDueDate(DateTime(2026, 7, 30), reference: reference),
        '7/30',
      );
      expect(
        DateFormatter.formatDueDate(DateTime(2026, 10, 30), reference: reference),
        '10/30',
      );
      expect(
        DateFormatter.formatDueDate(DateTime(2026, 12, 31), reference: reference),
        '12/31',
      );
    });

    test('今年以外は YYYY/M/D 形式', () {
      expect(
        DateFormatter.formatDueDate(DateTime(2027, 1, 5), reference: reference),
        '2027/1/5',
      );
    });
  });

  group('DateFormatter.buildTaskDueChipDisplay', () {
    final reference = DateTime(2026, 8, 13); // 木曜

    test('今日・明日・あとN日・期限切れを自然言語で返す', () {
      expect(
        DateFormatter.buildTaskDueChipDisplay(
          dueDate: DateTime(2026, 8, 13),
          reference: reference,
        ).headline,
        '🗓️ 今日',
      );
      expect(
        DateFormatter.buildTaskDueChipDisplay(
          dueDate: DateTime(2026, 8, 14),
          reference: reference,
        ).headline,
        '🗓️ 明日',
      );
      expect(
        DateFormatter.buildTaskDueChipDisplay(
          dueDate: DateTime(2026, 8, 16),
          reference: reference,
        ).headline,
        '🗓️ あと3日',
      );
      expect(
        DateFormatter.buildTaskDueChipDisplay(
          dueDate: DateTime(2026, 8, 10),
          reference: reference,
        ).headline,
        '🗓️ 期限切れ',
      );
    });

    test('日付サブ情報に曜日を含める', () {
      expect(
        DateFormatter.buildTaskDueChipDisplay(
          dueDate: DateTime(2026, 8, 17),
          reference: reference,
        ).subDateLabel,
        '8/17(月)',
      );
    });

    test('時間は従来形式のチップを維持する', () {
      final display = DateFormatter.buildTaskDueChipDisplay(
        dueDate: DateTime(2026, 8, 17),
        reminderTime: const TimeOfDay(hour: 10, minute: 30),
        reference: reference,
      );

      expect(display.timeLabel, '🕒10:30');
    });

    test('1行表示ラベルを組み立てる', () {
      final display = DateFormatter.buildTaskDueChipDisplay(
        dueDate: DateTime(2026, 8, 13),
        reminderTime: const TimeOfDay(hour: 12, minute: 0),
        reference: reference,
      );

      expect(display.inlineLabel, '🗓️ 今日　8/13(木)　🕒12:00');

      final upcoming = DateFormatter.buildTaskDueChipDisplay(
        dueDate: DateTime(2026, 8, 17),
        reminderTime: const TimeOfDay(hour: 9, minute: 5),
        reference: reference,
      );

      expect(upcoming.inlineLabel, '🗓️ あと4日　8/17(月)　🕒09:05');
    });

    test('緊急度に応じた色分けを返す', () {
      final colorScheme = const ColorScheme.light();
      const secondary = Color(0xFF8E8E93);

      expect(
        DateFormatter.dueDateChipForeground(
          DueDateUrgency.overdue,
          colorScheme: colorScheme,
          secondaryLabel: secondary,
        ),
        colorScheme.error,
      );
      expect(
        DateFormatter.dueDateChipForeground(
          DueDateUrgency.today,
          colorScheme: colorScheme,
          secondaryLabel: secondary,
        ),
        const Color(0xFFFF9500),
      );
      expect(
        DateFormatter.dueDateChipForeground(
          DueDateUrgency.tomorrow,
          colorScheme: colorScheme,
          secondaryLabel: secondary,
        ),
        const Color(0xFF007AFF),
      );
    });
  });

  group('DateFormatter reminder time', () {
    test('formatReminderTimeChip は 🕒 付きで表示する', () {
      expect(
        DateFormatter.formatReminderTimeChip(const TimeOfDay(hour: 10, minute: 30)),
        '🕒10:30',
      );
    });

    test('formatCalendarTaskTime は時刻絵文字付きで表示する', () {
      expect(
        DateFormatter.formatCalendarTaskTime(const TimeOfDay(hour: 9, minute: 0)),
        '🕘09:00',
      );
    });

    test('formatReminderTimeSheet は BottomSheet 向けにスペース付き', () {
      expect(
        DateFormatter.formatReminderTimeSheet(const TimeOfDay(hour: 9, minute: 0)),
        '🕘 09:00',
      );
    });
  });
}
