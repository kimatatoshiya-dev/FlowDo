import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/today_focus.dart';

/// FlowDo 専用アイコンアセット
abstract final class FlowDoIcons {
  static const calendar7 = 'assets/icons/calendar_7.svg';
}

/// 「7」入りカレンダー（7日以内）
class FlowDoCalendar7Icon extends StatelessWidget {
  const FlowDoCalendar7Icon({
    super.key,
    this.size = 18,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.onSurface;

    return SvgPicture.asset(
      FlowDoIcons.calendar7,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      semanticsLabel: '7日以内',
    );
  }
}

/// 今日やることの行頭アイコン
class TodayFocusLeadingIcon extends StatelessWidget {
  const TodayFocusLeadingIcon({
    super.key,
    required this.kind,
    this.size = 18,
    this.color,
  });

  final TodayFocusFilterKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      TodayFocusFilterKind.important => Text(
          '📌',
          style: TextStyle(fontSize: size, height: 1),
        ),
      TodayFocusFilterKind.dueToday => Text(
          '🔥',
          style: TextStyle(fontSize: size, height: 1),
        ),
      TodayFocusFilterKind.dueWithin7Days => Text(
          '🗓️',
          style: TextStyle(fontSize: size, height: 1),
        ),
    };
  }
}
