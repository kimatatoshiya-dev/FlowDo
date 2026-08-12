import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/notification_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';

/// タスクの期限日・時間を1フローで設定する BottomSheet
class TaskDueDateTimeSheet extends StatefulWidget {
  const TaskDueDateTimeSheet({
    super.key,
    required this.initialDueDate,
    required this.initialReminderTime,
    required this.onDueDateChanged,
    required this.onReminderTimeChanged,
    this.promptForTimeOnOpen = false,
  });

  final DateTime? initialDueDate;
  final TimeOfDay? initialReminderTime;
  final Future<void> Function(DateTime? dueDate) onDueDateChanged;
  final Future<void> Function(TimeOfDay? reminderTime) onReminderTimeChanged;
  final bool promptForTimeOnOpen;

  static Future<void> show(
    BuildContext context, {
    required DateTime? initialDueDate,
    required TimeOfDay? initialReminderTime,
    required Future<void> Function(DateTime? dueDate) onDueDateChanged,
    required Future<void> Function(TimeOfDay? reminderTime) onReminderTimeChanged,
    bool promptForTimeOnOpen = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => TaskDueDateTimeSheet(
        initialDueDate: initialDueDate,
        initialReminderTime: initialReminderTime,
        onDueDateChanged: onDueDateChanged,
        onReminderTimeChanged: onReminderTimeChanged,
        promptForTimeOnOpen: promptForTimeOnOpen,
      ),
    );
  }

  @override
  State<TaskDueDateTimeSheet> createState() => _TaskDueDateTimeSheetState();
}

class _TaskDueDateTimeSheetState extends State<TaskDueDateTimeSheet> {
  late DateTime? _dueDate;
  late TimeOfDay? _reminderTime;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.initialDueDate;
    _reminderTime = widget.initialReminderTime;

    if (widget.promptForTimeOnOpen && _dueDate != null && _reminderTime == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_promptForTime());
      });
    }
  }

  Future<void> _pickDate() async {
    if (_isSaving) return;

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (!mounted || picked == null) return;

    final due = DateTime(picked.year, picked.month, picked.day);
    final shouldPromptForTime = _reminderTime == null;

    setState(() => _dueDate = due);
    await _runSave(() => widget.onDueDateChanged(due));
    if (!mounted) return;

    if (shouldPromptForTime) {
      await _promptForTime();
    }
  }

  Future<void> _pickTime({bool clearIfCancelled = false}) async {
    if (_isSaving || _dueDate == null) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );
    if (!mounted) return;

    if (picked == null) {
      if (clearIfCancelled) {
        setState(() => _reminderTime = null);
        await _runSave(() => widget.onReminderTimeChanged(null));
      }
      return;
    }

    setState(() => _reminderTime = picked);
    await _runSave(() => widget.onReminderTimeChanged(picked));
  }

  Future<void> _promptForTime() async {
    if (!mounted || _dueDate == null) return;

    final shouldSetTime = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _TimePromptSheet(),
    );

    if (!mounted || shouldSetTime == null) return;

    if (shouldSetTime) {
      await _pickTime(clearIfCancelled: true);
      return;
    }

    setState(() => _reminderTime = null);
    await _runSave(() => widget.onReminderTimeChanged(null));
  }

  Future<void> _clearTime() async {
    if (_isSaving || _reminderTime == null) return;

    setState(() => _reminderTime = null);
    await _runSave(() => widget.onReminderTimeChanged(null));
  }

  Future<void> _runSave(Future<void> Function() action) async {
    setState(() => _isSaving = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final hasDueDate = _dueDate != null;

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
            const SizedBox(height: 4),
            Text(
              hasDueDate
                  ? '日付を選ぶと、続けて時間も設定できます'
                  : 'まず期限日を選んでください',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.secondaryLabel,
                  ),
            ),
            const SizedBox(height: 12),
            if (!hasDueDate)
              _SettingRow(
                key: const ValueKey('due_date_empty_row'),
                emoji: '📅',
                label: DateFormatter.noDueDateLabel,
                onTap: _pickDate,
                enabled: !_isSaving,
              )
            else ...[
              _DueDateTimeSummary(
                dueDate: _dueDate!,
                reminderTime: _reminderTime,
                onEditDate: _pickDate,
                onEditTime: () => _pickTime(),
                enabled: !_isSaving,
              ),
              if (_reminderTime != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSaving ? null : _clearTime,
                    child: const Text('時間をクリア'),
                  ),
                ),
              ],
            ],
            if (_reminderTime != null) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: colors.separator),
              const SizedBox(height: 4),
              _FutureNotificationRow(
                leadTimeLabel: NotificationLeadTime.minutes15.label,
              ),
            ],
            if (_isSaving) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: Text(
                  '完了',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueDateTimeSummary extends StatelessWidget {
  const _DueDateTimeSummary({
    required this.dueDate,
    required this.reminderTime,
    required this.onEditDate,
    required this.onEditTime,
    required this.enabled,
  });

  final DateTime dueDate;
  final TimeOfDay? reminderTime;
  final Future<void> Function() onEditDate;
  final Future<void> Function() onEditTime;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Material(
      color: colors.groupedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.separator.withValues(alpha: 0.9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _SettingRow(
            key: const ValueKey('due_date_set_row'),
            emoji: '📅',
            label: DateFormatter.format(dueDate),
            onTap: enabled ? onEditDate : null,
            enabled: enabled,
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: colors.separator),
          _SettingRow(
            key: const ValueKey('due_time_row'),
            emoji: '🕒',
            label: reminderTime == null
                ? DateFormatter.noReminderTimeLabel
                : DateFormatter.formatReminderTimeSheet(reminderTime!),
            onTap: enabled ? onEditTime : null,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

/// 将来のタスク別通知設定用プレースホルダー（今回は UI のみ）
class _FutureNotificationRow extends StatelessWidget {
  const _FutureNotificationRow({required this.leadTimeLabel});

  final String leadTimeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: false,
      leading: const Text('🔔', style: TextStyle(fontSize: 20, height: 1)),
      title: Text(
        '通知',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.secondaryLabel,
            ),
      ),
      subtitle: Text(
        '$leadTimeLabel（準備中）',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.secondaryLabel.withValues(alpha: 0.8),
            ),
      ),
      trailing: Icon(
        CupertinoIcons.lock_fill,
        size: 16,
        color: colors.secondaryLabel.withValues(alpha: 0.55),
      ),
    );
  }
}

class _TimePromptSheet extends StatelessWidget {
  const _TimePromptSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '時間も設定しますか？',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('時間を設定する'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '時間なし',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'あとから変更できます',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.secondaryLabel,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String emoji;
  final String label;
  final Future<void> Function()? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: Text(emoji, style: const TextStyle(fontSize: 20, height: 1)),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      trailing: onTap == null
          ? null
          : Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: Theme.of(context)
                  .extension<FlowDoColors>()!
                  .secondaryLabel
                  .withValues(alpha: 0.65),
            ),
      onTap: onTap == null ? null : () => unawaited(onTap!()),
    );
  }
}
