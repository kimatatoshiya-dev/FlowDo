import 'package:flutter/material.dart';

/// FlowDo のメイン CTA — Inbox タスクを未完了リストへ整理する
class OrganizeTasksButton extends StatelessWidget {
  const OrganizeTasksButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  static const flowDoBlue = Color(0xFF007AFF);

  final int count;
  final VoidCallback? onPressed;

  String get _label => count == 0 ? '整理する' : '$count件を整理する';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _label,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          key: const ValueKey('organize_tasks_button'),
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: flowDoBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: flowDoBlue.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🗂',
                style: TextStyle(fontSize: 18, height: 1.1),
              ),
              const SizedBox(width: 8),
              Text(
                _label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
