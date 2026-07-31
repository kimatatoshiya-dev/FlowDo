import 'package:flutter/material.dart';

import '../models/completed_task_retention.dart';
import '../models/feedback_preferences.dart';
import '../services/auth/auth_user.dart';
import '../theme/app_theme.dart';
import '../widgets/debug_crashlytics_panel.dart';

/// 設定画面
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.feedbackPreferences,
    required this.onFeedbackPreferencesChanged,
    required this.completedTaskRetention,
    required this.onCompletedTaskRetentionChanged,
    required this.onDeleteAllCompletedTasks,
    required this.authUser,
    required this.onSignOut,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final FeedbackPreferences feedbackPreferences;
  final ValueChanged<FeedbackPreferences> onFeedbackPreferencesChanged;
  final CompletedTaskRetention completedTaskRetention;
  final ValueChanged<CompletedTaskRetention> onCompletedTaskRetentionChanged;
  final Future<void> Function() onDeleteAllCompletedTasks;
  final AuthUser? authUser;
  final Future<void> Function() onSignOut;

  Future<void> _confirmDeleteAllCompletedTasks(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完了タスクをすべて削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onDeleteAllCompletedTasks();
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onSignOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              '外観',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: colors.groupedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _ThemeTile(
                    label: 'ライトモード',
                    icon: Icons.light_mode_outlined,
                    selected: themeMode == ThemeMode.light,
                    onTap: () => onThemeModeChanged(ThemeMode.light),
                    showDivider: true,
                  ),
                  _ThemeTile(
                    label: 'ダークモード',
                    icon: Icons.dark_mode_outlined,
                    selected: themeMode == ThemeMode.dark,
                    onTap: () => onThemeModeChanged(ThemeMode.dark),
                    showDivider: true,
                  ),
                  _ThemeTile(
                    label: 'システム設定に従う',
                    icon: Icons.brightness_auto_outlined,
                    selected: themeMode == ThemeMode.system,
                    onTap: () => onThemeModeChanged(ThemeMode.system),
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              '完了タスク',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: colors.groupedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (index, retention)
                      in CompletedTaskRetention.values.indexed)
                    _RetentionTile(
                      label: retention.label,
                      selected: completedTaskRetention == retention,
                      showDivider:
                          index < CompletedTaskRetention.values.length - 1,
                      onTap: () =>
                          onCompletedTaskRetentionChanged(retention),
                    ),
                  Divider(height: 1, color: colors.separator),
                  ListTile(
                    title: Text(
                      '完了タスクを一括削除',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    trailing: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onTap: () => _confirmDeleteAllCompletedTasks(context),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              'サウンドと触覚',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: colors.groupedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: const Text('効果音'),
                    subtitle: const Text('登録・完了・整理時の音'),
                    value: feedbackPreferences.soundEnabled,
                    onChanged: (enabled) {
                      onFeedbackPreferencesChanged(
                        feedbackPreferences.copyWith(soundEnabled: enabled),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 56, color: colors.separator),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_outlined),
                    title: const Text('ハプティック'),
                    subtitle: const Text('登録・完了・整理時の振動'),
                    value: feedbackPreferences.hapticEnabled,
                    onChanged: (enabled) {
                      onFeedbackPreferencesChanged(
                        feedbackPreferences.copyWith(hapticEnabled: enabled),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              'アカウント',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: colors.groupedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(authUser?.label ?? 'ログイン中'),
                    subtitle: Text(
                      authUser?.email ?? 'アカウント情報',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Divider(height: 1, indent: 56, color: colors.separator),
                  ListTile(
                    leading: Icon(
                      Icons.logout,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'ログアウト',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () => _confirmSignOut(context),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              'アプリ情報',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: colors.groupedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text('FlowDo'),
                subtitle: const Text('考えずに入力。整理はAI。行動に集中。'),
                trailing: Text(
                  'v1.0.0',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.secondaryLabel,
                      ),
                ),
              ),
            ),
          ),
          const DebugCrashlyticsPanel(),
        ],
      ),
    );
  }
}

class _RetentionTile extends StatelessWidget {
  const _RetentionTile({
    required this.label,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Column(
      children: [
        ListTile(
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_off_outlined,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(label),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(height: 1, indent: 56, color: colors.separator),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.showDivider,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: selected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: onTap,
        ),
        if (showDivider)
          Divider(height: 1, indent: 56, color: colors.separator),
      ],
    );
  }
}
