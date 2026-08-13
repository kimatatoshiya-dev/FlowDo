import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/task_repeat_type.dart';

void main() {
  Task sampleTask({
    required int id,
    required String title,
    TaskRepeatType repeatType = TaskRepeatType.none,
    bool isCompleted = false,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      title: title,
      isInbox: false,
      repeatType: repeatType,
      isCompleted: isCompleted,
      completedAt: completedAt,
    );
  }

  group('TaskRepeatTypeLabels', () {
    test('storage round-trip', () {
      expect(TaskRepeatTypeLabels.fromStorage('daily'), TaskRepeatType.daily);
      expect(TaskRepeatTypeLabels.fromStorage('weekly'), TaskRepeatType.weekly);
      expect(TaskRepeatTypeLabels.fromStorage(null), TaskRepeatType.none);
      expect(TaskRepeatTypeLabels.fromStorage('unknown'), TaskRepeatType.none);
    });
  });

  group('DailyRoutineLogic', () {
    final today = DateTime(2026, 8, 13, 10, 0);
    final yesterday = DateTime(2026, 8, 12, 22, 0);

    test('isCompletedToday は daily タスクの当日完了のみ true', () {
      final completedToday = sampleTask(
        id: 1,
        title: '朝活',
        repeatType: TaskRepeatType.daily,
        isCompleted: true,
        completedAt: today,
      );
      final completedYesterday = sampleTask(
        id: 2,
        title: '夜活',
        repeatType: TaskRepeatType.daily,
        isCompleted: true,
        completedAt: yesterday,
      );

      expect(DailyRoutineLogic.isCompletedToday(completedToday, today), isTrue);
      expect(
        DailyRoutineLogic.isCompletedToday(completedYesterday, today),
        isFalse,
      );
    });

    test('resetExpiredDailyTasks は前日完了の daily を未完了へ戻す', () {
      final tasks = [
        sampleTask(
          id: 1,
          title: '朝活',
          repeatType: TaskRepeatType.daily,
          isCompleted: true,
          completedAt: yesterday,
        ),
        sampleTask(
          id: 2,
          title: '通常',
          isCompleted: true,
          completedAt: yesterday,
        ),
      ];

      expect(DailyRoutineLogic.resetExpiredDailyTasks(tasks, referenceNow: today), isTrue);
      expect(tasks[0].isCompleted, isFalse);
      expect(tasks[0].completedAt, isNull);
      expect(tasks[1].isCompleted, isTrue);
    });
  });

  group('todayRoutineTasks', () {
    test('repeatType が none 以外を返す', () {
      final result = todayRoutineTasks(
        tasks: [
          sampleTask(id: 1, title: '英語', repeatType: TaskRepeatType.daily),
          sampleTask(id: 2, title: '会議', repeatType: TaskRepeatType.none),
          sampleTask(id: 3, title: '筋トレ', repeatType: TaskRepeatType.daily),
          sampleTask(id: 4, title: '月次', repeatType: TaskRepeatType.monthly),
        ],
      );

      expect(result.map((task) => task.title), ['月次', '筋トレ', '英語']);
    });
  });

  group('Task JSON', () {
    test('repeatType を保存・復元する', () {
      final task = sampleTask(
        id: 1,
        title: '朝活',
        repeatType: TaskRepeatType.daily,
      );

      final restored = Task.fromJson(task.toJson());
      expect(restored.repeatType, TaskRepeatType.daily);
    });

    test('repeatType 未設定は none', () {
      final restored = Task.fromJson({
        'id': 1,
        'title': 'legacy',
      });
      expect(restored.repeatType, TaskRepeatType.none);
    });
  });
}
