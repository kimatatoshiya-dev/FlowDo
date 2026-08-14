import 'package:flutter/material.dart';

import 'today_memo_section.dart';

/// ホーム画面ショートカットから開く今日メモ BottomSheet
class TodayMemoSheet extends StatelessWidget {
  const TodayMemoSheet({
    super.key,
    required this.memoText,
    required this.onMemoChanged,
  });

  static const sheetHeightFactor = 0.62;

  final String memoText;
  final Future<void> Function(String text) onMemoChanged;

  static Future<void> show(
    BuildContext context, {
    required String memoText,
    required Future<void> Function(String text) onMemoChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => TodayMemoSheet(
        memoText: memoText,
        onMemoChanged: onMemoChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * sheetHeightFactor;

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: TodayMemoSection(
            memoText: memoText,
            onMemoChanged: onMemoChanged,
          ),
        ),
      ),
    );
  }
}
