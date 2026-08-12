import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'organize_tasks_button.dart';

/// Inbox の整理進捗（思考整理モード）
class InboxOrganizationProgress extends StatelessWidget {
  const InboxOrganizationProgress({
    super.key,
    required this.organizedCount,
    required this.totalCount,
  });

  final int organizedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    if (totalCount <= 0) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<FlowDoColors>();
    final secondary = colors?.secondaryLabel ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final segmentCount = totalCount.clamp(1, 10);
    final filledSegments =
        ((organizedCount / totalCount) * segmentCount).round().clamp(0, segmentCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '整理中',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < segmentCount; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < filledSegments
                          ? OrganizeTasksButton.flowDoBlue
                          : OrganizeTasksButton.flowDoBlue.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$organizedCount / $totalCount',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
          ),
        ],
      ),
    );
  }
}
