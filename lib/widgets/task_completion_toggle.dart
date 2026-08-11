import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 未完了リストと同じ ○ 完了トグル
class TaskCompletionToggle extends StatelessWidget {
  const TaskCompletionToggle({
    super.key,
    required this.completed,
    required this.onTap,
    this.size = 24,
    this.compact = false,
  });

  final bool completed;
  final VoidCallback onTap;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final iconSize = compact ? 14.0 : 16.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: completed
              ? colorScheme.primary
              : Colors.transparent,
          border: Border.all(
            color: completed ? colorScheme.primary : colors.secondaryLabel,
            width: 2,
          ),
        ),
        child: completed
            ? Icon(Icons.check, size: iconSize, color: Colors.white)
            : null,
      ),
    );
  }
}
