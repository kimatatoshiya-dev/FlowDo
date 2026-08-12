import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';

/// タスクの期限日・時間を設定する BottomSheet
class TaskDueDateTimeSheet extends StatelessWidget {
  const TaskDueDateTimeSheet({
    super.key,
    required this.dueDate,
    required this.reminderTime,
    required this.onPickDate,
    required this.onPickTime,
    required this.onClearTime,
  });

  final DateTime? dueDate;
  final TimeOfDay? reminderTime;
  final Future<void> Function() onPickDate;
  final Future<void> Function() onPickTime;
  final Future<void> Function() onClearTime;

  static Future<void> show(
    BuildContext context, {
    required DateTime? dueDate,
    required TimeOfDay? reminderTime,
    required Future<void> Function() onPickDate,
    required Future<void> Function() onPickTime,
    required Future<void> Function() onClearTime,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => TaskDueDateTimeSheet(
        dueDate: dueDate,
        reminderTime: reminderTime,
        onPickDate: onPickDate,
        onPickTime: onPickTime,
        onClearTime: onClearTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final canPickTime = dueDate != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '期限と時間',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            _SettingRow(
              emoji: '📅',
              label: dueDate == null
                  ? DateFormatter.noDueDateLabel
                  : DateFormatter.format(dueDate!),
              onTap: onPickDate,
            ),
            Divider(height: 1, color: colors.separator),
            _SettingRow(
              emoji: '🕒',
              label: reminderTime == null
                  ? DateFormatter.noReminderTimeLabel
                  : DateFormatter.formatReminderTime(reminderTime!),
              onTap: canPickTime ? onPickTime : null,
              subtitle: canPickTime
                  ? null
                  : '日付を先に設定してください',
              trailing: reminderTime != null && canPickTime
                  ? TextButton(
                      onPressed: onClearTime,
                      child: const Text('クリア'),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.emoji,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String emoji;
  final String label;
  final Future<void> Function()? onTap;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(emoji, style: const TextStyle(fontSize: 20, height: 1)),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.secondaryLabel,
                  ),
            ),
      trailing: trailing,
      onTap: onTap == null ? null : () { unawaited(onTap!()); },
    );
  }
}
