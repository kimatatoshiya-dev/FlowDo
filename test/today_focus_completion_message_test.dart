import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/today_focus.dart';
import 'package:flowdo/models/today_focus_completion_message.dart';
import 'package:flowdo/models/task.dart';

import 'flowdo_test_helpers.dart';

class _FakeRandom implements Random {
  _FakeRandom({
    required this.doubles,
    this.ints = const [],
  });

  final List<double> doubles;
  final List<int> ints;
  var _doubleIndex = 0;
  var _intIndex = 0;

  @override
  double nextDouble() => doubles[_doubleIndex++];

  @override
  int nextInt(int max) {
    if (ints.isEmpty) return 0;
    return ints[_intIndex++ % ints.length] % max;
  }

  @override
  bool nextBool() => nextDouble() >= 0.5;
}

List<TodayFocusSectionData> _singleImportantSection(int taskId) {
  return [
    TodayFocusSectionData(
      kind: TodayFocusFilterKind.important,
      label: '重要',
      tasks: [
        TodayFocusTaskItem(taskId: taskId, title: '重要タスク'),
      ],
    ),
    const TodayFocusSectionData(
      kind: TodayFocusFilterKind.dueToday,
      label: '今日期限',
      tasks: [],
    ),
    const TodayFocusSectionData(
      kind: TodayFocusFilterKind.dueWithin7Days,
      label: '7日以内',
      tasks: [],
    ),
  ];
}

Finder _taskCheckbox(String title) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(title, skipOffstage: false),
      matching: find.byType(Dismissible),
    ),
    matching: find.byType(AnimatedContainer),
  );
}

Future<void> _completeTask(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title, skipOffstage: false));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(_taskCheckbox(title));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  group('TodayFocusCompletionMessages', () {
    test('通常メッセージは10種類ある', () {
      expect(TodayFocusCompletionMessages.normalMessages, hasLength(10));
    });

    test('レア確率でレアメッセージを返す', () {
      final picker = TodayFocusCompletionMessages(
        random: _FakeRandom(doubles: [0.0]),
      );

      final message = picker.pick();

      expect(message.isRare, isTrue);
      expect(message.text, TodayFocusCompletionMessages.rareMessage.text);
    });

    test('通常メッセージは連続で同じにならない', () {
      final picker = TodayFocusCompletionMessages(
        random: _FakeRandom(
          doubles: [1.0, 1.0],
          ints: [0, 0],
        ),
      );

      final first = picker.pick();
      final second = picker.pick();

      expect(first.isRare, isFalse);
      expect(second.isRare, isFalse);
      expect(first.text, isNot(equals(second.text)));
    });

    test('レアのあとも通常メッセージを返せる', () {
      final picker = TodayFocusCompletionMessages(
        random: _FakeRandom(
          doubles: [0.0, 1.0],
          ints: [0],
        ),
      );

      expect(picker.pick().isRare, isTrue);
      expect(picker.pick().isRare, isFalse);
    });
  });

  group('isLastRemainingTodayFocusTask', () {
    test('残り1件のときだけ true', () {
      final entries = flattenTodayFocusSections(_singleImportantSection(1));

      expect(isLastRemainingTodayFocusTask(entries, 1), isTrue);
      expect(isLastRemainingTodayFocusTask(entries, 2), isFalse);
    });

    test('複数件あるときは false', () {
      final sections = [
        const TodayFocusSectionData(
          kind: TodayFocusFilterKind.important,
          label: '重要',
          tasks: [
            TodayFocusTaskItem(taskId: 1, title: 'a'),
            TodayFocusTaskItem(taskId: 2, title: 'b'),
          ],
        ),
      ];
      final entries = flattenTodayFocusSections(sections);

      expect(isLastRemainingTodayFocusTask(entries, 1), isFalse);
    });
  });

  testWidgets('今日の重要タスクをすべて完了したときだけメッセージを表示する',
      (WidgetTester tester) async {
    await pumpFlowDoApp(
      tester,
      initialPreferences: {
        'flowdo_tasks':
            '[{"id":0,"title":"重要A","isInbox":false,"isFavorite":true,"pinnedAt":"2026-01-01T00:00:00.000"},{"id":1,"title":"重要B","isInbox":false,"isFavorite":true,"pinnedAt":"2026-01-02T00:00:00.000"}]',
      },
    );
    Task.syncNextId([
      Task(id: 0, title: '重要A', isInbox: false, isFavorite: true),
      Task(id: 1, title: '重要B', isInbox: false, isFavorite: true),
    ]);

    await _completeTask(tester, '重要A');
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsNothing);

    await _completeTask(tester, '重要B');
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 300));

    final allTexts = [
      ...TodayFocusCompletionMessages.normalMessages,
      TodayFocusCompletionMessages.rareMessage.text,
    ];
    final shown = allTexts.any(
      (text) => find.text(text, skipOffstage: false).evaluate().isNotEmpty,
    );
    expect(shown, isTrue);
  });

  testWidgets('重要タスクがない場合は完了してもメッセージを表示しない',
      (WidgetTester tester) async {
    await pumpFlowDoApp(
      tester,
      initialPreferences: {
        'flowdo_tasks':
            '[{"id":0,"title":"通常タスク","isInbox":false,"isFavorite":false}]',
      },
    );
    Task.syncNextId([Task(id: 0, title: '通常タスク', isInbox: false)]);

    await _completeTask(tester, '通常タスク');
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsNothing);
  });
}
