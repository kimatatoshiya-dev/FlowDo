import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// FlowDo 入力キャンバス（白背景・影と角丸のみ）
class FlowDoFlowCanvas extends StatelessWidget {
  const FlowDoFlowCanvas({
    super.key,
    required this.isFocused,
    required this.isDark,
    required this.child,
  });

  final bool isFocused;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
        border: Border.all(
          color: isFocused
              ? colorScheme.primary
              : isDark
                  ? colors.separator
                  : const Color(0xFFD9D9D9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: isFocused ? 12 : 8,
            offset: Offset(0, isFocused ? 3 : 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
