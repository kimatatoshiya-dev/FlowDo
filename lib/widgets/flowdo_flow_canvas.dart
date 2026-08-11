import 'package:flutter/material.dart';

/// FlowDo 入力キャンバス（背景・枠線で入力エリアを強調）
class FlowDoFlowCanvas extends StatelessWidget {
  const FlowDoFlowCanvas({
    super.key,
    required this.isFocused,
    required this.isDark,
    required this.child,
    this.showGuidance = false,
  });

  final bool isFocused;
  final bool isDark;
  final Widget child;
  final bool showGuidance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseBorderColor = isFocused
        ? colorScheme.primary
        : colorScheme.primary.withValues(alpha: isDark ? 0.55 : 0.42);

    final canvasColor = isDark
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: isFocused ? 0.1 : 0.07),
            const Color(0xFF1C1C1E),
          )
        : Color.alphaBlend(
            colorScheme.primary.withValues(alpha: isFocused ? 0.06 : 0.045),
            const Color(0xFFFFFFFF),
          );

    final canvas = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: canvasColor,
        border: Border.all(
          color: baseBorderColor,
          width: isFocused ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(
              alpha: isFocused ? 0.14 : 0.08,
            ),
            blurRadius: isFocused ? 16 : 10,
            offset: Offset(0, isFocused ? 4 : 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: isFocused ? 12 : 8,
            offset: Offset(0, isFocused ? 3 : 2),
          ),
        ],
      ),
      child: child,
    );

    if (!showGuidance) return canvas;

    final bubbleColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        canvas,
        Positioned(
          left: 14,
          top: -13,
          child: Material(
            color: bubbleColor,
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? colorScheme.outlineVariant
                      : colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                'ここから入力',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
