import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/notification_preferences.dart';
import '../models/task_repeat_type.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';

/// タスクの期限日・時間・繰り返し・通知を1画面で設定する BottomSheet
class TaskDueDateTimeSheet extends StatefulWidget {
  const TaskDueDateTimeSheet({
    super.key,
    required this.initialDueDate,
    required this.initialReminderTime,
    required this.initialRepeatType,
    required this.notificationPreferences,
    required this.notificationsFeatureEnabled,
    required this.checkNotificationPermission,
    required this.onRequestNotificationPermission,
    required this.onDueDateChanged,
    required this.onReminderTimeChanged,
    required this.onRepeatTypeChanged,
    this.onNotificationReschedule,
    this.promptForTimeOnOpen = false,
  });

  final DateTime? initialDueDate;
  final TimeOfDay? initialReminderTime;
  final TaskRepeatType initialRepeatType;
  final NotificationPreferences notificationPreferences;
  final bool notificationsFeatureEnabled;
  final Future<bool> Function() checkNotificationPermission;
  final Future<bool> Function() onRequestNotificationPermission;
  final Future<void> Function(DateTime? dueDate) onDueDateChanged;
  final Future<void> Function(TimeOfDay? reminderTime) onReminderTimeChanged;
  final Future<void> Function(TaskRepeatType repeatType) onRepeatTypeChanged;
  final Future<void> Function()? onNotificationReschedule;
  final bool promptForTimeOnOpen;

  static Future<void> show(
    BuildContext context, {
    required DateTime? initialDueDate,
    required TimeOfDay? initialReminderTime,
    required TaskRepeatType initialRepeatType,
    required NotificationPreferences notificationPreferences,
    required bool notificationsFeatureEnabled,
    required Future<bool> Function() checkNotificationPermission,
    required Future<bool> Function() onRequestNotificationPermission,
    required Future<void> Function(DateTime? dueDate) onDueDateChanged,
    required Future<void> Function(TimeOfDay? reminderTime) onReminderTimeChanged,
    required Future<void> Function(TaskRepeatType repeatType) onRepeatTypeChanged,
    Future<void> Function()? onNotificationReschedule,
    bool promptForTimeOnOpen = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => TaskDueDateTimeSheet(
        initialDueDate: initialDueDate,
        initialReminderTime: initialReminderTime,
        initialRepeatType: initialRepeatType,
        notificationPreferences: notificationPreferences,
        notificationsFeatureEnabled: notificationsFeatureEnabled,
        checkNotificationPermission: checkNotificationPermission,
        onRequestNotificationPermission: onRequestNotificationPermission,
        onDueDateChanged: onDueDateChanged,
        onReminderTimeChanged: onReminderTimeChanged,
        onRepeatTypeChanged: onRepeatTypeChanged,
        onNotificationReschedule: onNotificationReschedule,
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
  late TaskRepeatType _repeatType;
  var _isSaving = false;
  var _permissionGranted = false;
  var _permissionChecked = false;
  var _permissionRequesting = false;

  bool get _notificationsEnabled =>
      widget.notificationsFeatureEnabled &&
      widget.notificationPreferences.enabled &&
      widget.notificationPreferences.leadTime != NotificationLeadTime.none;

  bool get _showsFullScheduleSettings =>
      _dueDate != null || _repeatType != TaskRepeatType.none;

  bool get _canPickTime =>
      _dueDate != null || _repeatType == TaskRepeatType.daily;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.initialDueDate;
    _reminderTime = widget.initialReminderTime;
    _repeatType = widget.initialRepeatType;
    unawaited(_refreshPermissionStatus());

    if (widget.promptForTimeOnOpen && _canPickTime && _reminderTime == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_promptForTime());
      });
    }
  }

  Future<void> _refreshPermissionStatus() async {
    final granted = await widget.checkNotificationPermission();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _permissionChecked = true;
    });
  }

  Future<void> _requestPermission() async {
    if (_permissionRequesting) return;
    setState(() => _permissionRequesting = true);
    try {
      final granted = await widget.onRequestNotificationPermission();
      await _refreshPermissionStatus();
      if (granted) {
        await widget.onNotificationReschedule?.call();
      }
    } finally {
      if (mounted) {
        setState(() => _permissionRequesting = false);
      }
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
    if (_isSaving || !_canPickTime) return;

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
    if (!mounted) return;
    await _refreshPermissionStatus();
  }

  Future<void> _promptForTime() async {
    if (!mounted || !_canPickTime) return;

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

  Future<void> _pickRepeatType() async {
    if (_isSaving) return;

    final selected = await showModalBottomSheet<TaskRepeatType>(
      context: context,
      showDragHandle: true,
      builder: (context) => _RepeatTypePickerSheet(initialValue: _repeatType),
    );
    if (!mounted || selected == null || selected == _repeatType) return;

    if (selected != TaskRepeatType.daily &&
        selected != TaskRepeatType.none &&
        _dueDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('毎週・毎月・毎年の繰り返しには期限日が必要です'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    setState(() => _repeatType = selected);
    await _runSave(() => widget.onRepeatTypeChanged(selected));
  }

  Future<void> _finishSheet() async {
    if (_isSaving) return;
    await widget.onNotificationReschedule?.call();
    if (!mounted) return;
    Navigator.pop(context);
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
              _showsFullScheduleSettings
                  ? '日付・時間・繰り返し・通知をまとめて設定できます'
                  : 'まず期限日を選んでください',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.secondaryLabel,
                  ),
            ),
            const SizedBox(height: 12),
            if (!_showsFullScheduleSettings)
              _SettingRow(
                key: const ValueKey('due_date_empty_row'),
                emoji: '📅',
                label: DateFormatter.noDueDateLabel,
                onTap: _pickDate,
                enabled: !_isSaving,
              )
            else ...[
              _TaskScheduleSettingsCard(
                dueDate: _dueDate,
                reminderTime: _reminderTime,
                repeatType: _repeatType,
                canPickTime: _canPickTime,
                notificationsFeatureEnabled: widget.notificationsFeatureEnabled,
                notificationsEnabled: _notificationsEnabled,
                permissionChecked: _permissionChecked,
                permissionGranted: _permissionGranted,
                permissionRequesting: _permissionRequesting,
                leadTimeLabel: widget.notificationPreferences.leadTime.label,
                onEditDate: _pickDate,
                onEditTime: () => _pickTime(),
                onEditRepeat: _pickRepeatType,
                onRequestPermission: _requestPermission,
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
                onPressed: _isSaving ? null : () => unawaited(_finishSheet()),
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

class _TaskScheduleSettingsCard extends StatelessWidget {
  const _TaskScheduleSettingsCard({
    required this.dueDate,
    required this.reminderTime,
    required this.repeatType,
    required this.canPickTime,
    required this.notificationsFeatureEnabled,
    required this.notificationsEnabled,
    required this.permissionChecked,
    required this.permissionGranted,
    required this.permissionRequesting,
    required this.leadTimeLabel,
    required this.onEditDate,
    required this.onEditTime,
    required this.onEditRepeat,
    required this.onRequestPermission,
    required this.enabled,
  });

  final DateTime? dueDate;
  final TimeOfDay? reminderTime;
  final TaskRepeatType repeatType;
  final bool canPickTime;
  final bool notificationsFeatureEnabled;
  final bool notificationsEnabled;
  final bool permissionChecked;
  final bool permissionGranted;
  final bool permissionRequesting;
  final String leadTimeLabel;
  final Future<void> Function() onEditDate;
  final Future<void> Function() onEditTime;
  final Future<void> Function() onEditRepeat;
  final VoidCallback onRequestPermission;
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
            label: dueDate == null
                ? DateFormatter.noDueDateLabel
                : DateFormatter.format(dueDate!),
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
            onTap: enabled && canPickTime ? onEditTime : null,
            enabled: enabled && canPickTime,
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: colors.separator),
          _SettingRow(
            key: const ValueKey('due_repeat_row'),
            emoji: '🔁',
            label: repeatType.label,
            onTap: enabled ? onEditRepeat : null,
            enabled: enabled,
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: colors.separator),
          _TaskNotificationStatusRow(
            notificationsFeatureEnabled: notificationsFeatureEnabled,
            notificationsEnabled: notificationsEnabled,
            hasReminderTime: reminderTime != null,
            permissionChecked: permissionChecked,
            permissionGranted: permissionGranted,
            permissionRequesting: permissionRequesting,
            leadTimeLabel: leadTimeLabel,
            onRequestPermission: onRequestPermission,
          ),
        ],
      ),
    );
  }
}

class _TaskNotificationStatusRow extends StatelessWidget {
  const _TaskNotificationStatusRow({
    required this.notificationsFeatureEnabled,
    required this.notificationsEnabled,
    required this.hasReminderTime,
    required this.permissionChecked,
    required this.permissionGranted,
    required this.permissionRequesting,
    required this.leadTimeLabel,
    required this.onRequestPermission,
  });

  final bool notificationsFeatureEnabled;
  final bool notificationsEnabled;
  final bool hasReminderTime;
  final bool permissionChecked;
  final bool permissionGranted;
  final bool permissionRequesting;
  final String leadTimeLabel;
  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    if (!hasReminderTime) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Text('🔔', style: TextStyle(fontSize: 20, height: 1)),
        title: const Text('通知'),
        subtitle: Text(
          '時間を設定すると通知されます',
          style: TextStyle(color: colors.secondaryLabel),
        ),
        trailing: Text(
          'OFF',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    if (!notificationsEnabled) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Text('🔔', style: TextStyle(fontSize: 20, height: 1)),
        title: const Text('通知'),
        subtitle: Text(
          notificationsFeatureEnabled
              ? '設定で通知がOFFです'
              : '現在利用できません',
          style: TextStyle(color: colors.secondaryLabel),
        ),
        trailing: Text(
          'OFF',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    if (!permissionChecked) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Text('🔔', style: TextStyle(fontSize: 20, height: 1)),
        title: const Text('通知'),
        subtitle: Text(
          leadTimeLabel,
          style: TextStyle(color: colors.secondaryLabel),
        ),
        trailing: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!permissionGranted) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Text('🔔', style: TextStyle(fontSize: 20, height: 1)),
        title: const Text('通知'),
        subtitle: Text(
          '$leadTimeLabel · 通知の許可が必要です',
          style: TextStyle(color: colors.secondaryLabel),
        ),
        trailing: permissionRequesting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onRequestPermission,
                child: const Text('許可する'),
              ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Text('🔔', style: TextStyle(fontSize: 20, height: 1)),
      title: const Text('通知'),
      subtitle: Text(
        leadTimeLabel,
        style: TextStyle(color: colors.secondaryLabel),
      ),
      trailing: Text(
        'ON',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _RepeatTypePickerSheet extends StatelessWidget {
  const _RepeatTypePickerSheet({required this.initialValue});

  final TaskRepeatType initialValue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '🔁 繰り返し',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            for (final (index, type) in TaskRepeatType.values.indexed) ...[
              if (index > 0)
                Divider(height: 1, color: colors.separator),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(type.label),
                trailing: type == initialValue
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, type),
              ),
            ],
          ],
        ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
