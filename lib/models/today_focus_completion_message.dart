import 'dart:math';

import 'today_focus.dart';

/// 今日の重要タスク完了メッセージ
class TodayFocusCompletionMessage {
  const TodayFocusCompletionMessage({
    required this.text,
    required this.isRare,
  });

  final String text;
  final bool isRare;
}

/// FlowDo 完了メッセージの抽選
class TodayFocusCompletionMessages {
  TodayFocusCompletionMessages({Random? random})
      : _random = random ?? Random();

  static const rareProbability = 0.01;

  static const rareMessage = TodayFocusCompletionMessage(
    text: '🏆 レア！\n今日はFlowDoもご機嫌です。',
    isRare: true,
  );

  static const normalMessages = [
    '頭の中が、少しすっきりしました。',
    '今日の重要タスク、すべて片づきました。',
    'ここまで来れば、十分です。',
    '今日の優先事項はクリアです。',
    '余白ができました。次に進みましょう。',
    '大事なところだけ、終わらせられました。',
    '今日の焦点は、ここまでです。',
    '整理された一日、いい感じです。',
    '頭のノイズが、ひとつ減りました。',
    '今日やるべきこと、お疲れさまでした。',
  ];

  final Random _random;
  int? _lastNormalIndex;

  TodayFocusCompletionMessage pick() {
    if (_random.nextDouble() < rareProbability) {
      return rareMessage;
    }

    final candidates = [
      for (var i = 0; i < normalMessages.length; i++)
        if (i != _lastNormalIndex) i,
    ];

    final index = candidates[_random.nextInt(candidates.length)];
    _lastNormalIndex = index;

    return TodayFocusCompletionMessage(
      text: normalMessages[index],
      isRare: false,
    );
  }
}

/// 完了操作で最後の1件かどうか
bool isLastRemainingTodayFocusTask(
  List<TodayFocusListEntry> entries,
  int taskId,
) {
  return entries.length == 1 && entries.first.task.taskId == taskId;
}
