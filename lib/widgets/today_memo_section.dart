import 'package:flutter/material.dart';

import '../screens/today_page.dart';
import 'daily_memo_editor.dart';

/// Today 画面と同じ「📝 今日メモ」セクション
class TodayMemoSection extends StatelessWidget {
  const TodayMemoSection({
    super.key,
    required this.memoText,
    this.onMemoChanged,
  });

  final String memoText;
  final Future<void> Function(String text)? onMemoChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '📝 今日メモ',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.15,
              ),
        ),
        const SizedBox(height: 12),
        if (onMemoChanged == null)
          Container(
            constraints: const BoxConstraints(minHeight: 140),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(TodayPage.cardRadius),
            ),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.topLeft,
            child: Text(
              memoText.isEmpty
                  ? '今日の気付き・反省・アイデアを書きましょう'
                  : memoText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    height: 1.45,
                  ),
            ),
          )
        else
          DailyMemoEditor(
            initialText: memoText,
            onSave: onMemoChanged!,
          ),
      ],
    );
  }
}
