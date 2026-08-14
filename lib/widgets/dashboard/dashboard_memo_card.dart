import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'dashboard_surface_card.dart';

/// Dashboard 下部の今日メモプレビュー
class DashboardMemoCard extends StatelessWidget {
  const DashboardMemoCard({
    super.key,
    required this.memoText,
    this.onTap,
    this.maxPreviewLines = 3,
  });

  final String memoText;
  final VoidCallback? onTap;
  final int maxPreviewLines;

  static String previewText(String memoText, {int maxLines = 3}) {
    final trimmed = memoText.trim();
    if (trimmed.isEmpty) {
      return '今日の気付き・反省・アイデアを書きましょう';
    }

    return trimmed
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(maxLines)
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final preview = previewText(memoText, maxLines: maxPreviewLines);
    final isEmpty = memoText.trim().isEmpty;

    return DashboardSurfaceCard(
      key: const ValueKey('dashboard_memo_card'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '📝 今日メモ',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            preview,
            maxLines: maxPreviewLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.45,
                  color: isEmpty
                      ? colors.secondaryLabel
                      : Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}
