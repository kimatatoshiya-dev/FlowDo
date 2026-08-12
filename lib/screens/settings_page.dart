import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_features.dart';
import '../config/app_links.dart';
import '../models/completed_task_retention.dart';
import '../models/feedback_preferences.dart';
import '../models/notification_preferences.dart';
import '../services/app_version_info.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/auth_user.dart';
import '../theme/app_theme.dart';
import '../utils/external_link_launcher.dart';
import '../widgets/debug_crashlytics_panel.dart';
import '../widgets/settings_group.dart';
import 'about_page.dart';

/// 設定画面
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.feedbackPreferences,
    required this.onFeedbackPreferencesChanged,
    required this.notificationPreferences,
    required this.onNotificationPreferencesChanged,
    required this.completedTaskRetention,
    required this.onCompletedTaskRetentionChanged,
    required this.onDeleteAllCompletedTasks,
    required this.authService,
    required this.onSignInWithGoogle,
    required this.onSignInWithApple,
    required this.onSignOut,
    this.versionInfo,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final FeedbackPreferences feedbackPreferences;
  final ValueChanged<FeedbackPreferences> onFeedbackPreferencesChanged;
  final NotificationPreferences notificationPreferences;
  final ValueChanged<NotificationPreferences> onNotificationPreferencesChanged;
  final CompletedTaskRetention completedTaskRetention;
  final ValueChanged<CompletedTaskRetention> onCompletedTaskRetentionChanged;
  final Future<void> Function() onDeleteAllCompletedTasks;
  final AuthService authService;
  final Future<void> Function() onSignInWithGoogle;
  final Future<void> Function() onSignInWithApple;
  final Future<void> Function() onSignOut;
  final AppVersionInfo? versionInfo;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _appleSignInAvailable = false;
  bool _isSigningIn = false;
  AppVersionInfo? _versionInfo;

  @override
  void initState() {
    super.initState();
    _versionInfo = widget.versionInfo;
    unawaited(_loadAppleAvailability());
    if (_versionInfo == null) {
      unawaited(_loadVersionInfo());
    }
  }

  Future<void> _loadAppleAvailability() async {
    final available = await widget.authService.isAppleSignInAvailable;
    if (!mounted) return;
    setState(() => _appleSignInAvailable = available);
  }

  Future<void> _loadVersionInfo() async {
    final info = await AppVersionInfo.load();
    if (!mounted) return;
    setState(() => _versionInfo = info);
  }

  Future<void> _runSignIn(Future<void> Function() action) async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _confirmDeleteAllCompletedTasks() async {
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
      await widget.onDeleteAllCompletedTasks();
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？\n端末内のタスクはそのまま使えます。'),
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
      await widget.onSignOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _openAboutPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AboutPage(versionInfo: _versionInfo),
      ),
    );
  }

  Future<void> _openExternalLink(Uri uri) {
    return ExternalLinkLauncher.launch(context, uri);
  }

  Widget _accountSection(AuthUser? authUser) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    if (authUser == null) {
      return SettingsGroup(
        children: [
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('ゲスト利用中'),
            subtitle: Text('タスクはこの端末に保存されています'),
          ),
          if (_isSigningIn)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Divider(height: 1, indent: 56, color: colors.separator),
            ListTile(
              leading: const Icon(Icons.g_mobiledata_rounded),
              title: const Text('Google でログイン'),
              subtitle: const Text('クラウド同期とデータ移行'),
              onTap: () => _runSignIn(widget.onSignInWithGoogle),
            ),
            if (_appleSignInAvailable) ...[
              Divider(height: 1, indent: 56, color: colors.separator),
              ListTile(
                leading: const Icon(Icons.apple),
                title: const Text('Apple でログイン'),
                subtitle: const Text('クラウド同期とデータ移行'),
                onTap: () => _runSignIn(widget.onSignInWithApple),
              ),
            ],
          ],
        ],
      );
    }

    return SettingsGroup(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(authUser.label),
          subtitle: Text(
            authUser.email ?? 'クラウド同期中',
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
          onTap: _confirmSignOut,
        ),
      ],
    );
  }

  Widget _aboutSection() {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final versionLabel = _versionInfo?.displayLabel ?? '読み込み中…';

    return SettingsGroup(
      children: [
        SettingsLinkTile(
          icon: Icons.info_outline,
          title: 'アプリについて',
          subtitle: kAppTagline,
          onTap: _openAboutPage,
        ),
        SettingsLinkTile(
          icon: Icons.tag_outlined,
          title: 'バージョン',
          showDivider: false,
          trailing: Text(
            versionLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.secondaryLabel,
                ),
          ),
          onTap: null,
        ),
      ],
    );
  }

  Widget _supportSection() {
    return SettingsGroup(
      children: [
        SettingsLinkTile(
          icon: Icons.description_outlined,
          title: '利用規約',
          onTap: () => _openExternalLink(AppLinks.termsOfServiceUri),
        ),
        SettingsLinkTile(
          icon: Icons.privacy_tip_outlined,
          title: 'プライバシーポリシー',
          onTap: () => _openExternalLink(AppLinks.privacyPolicyUri),
        ),
        SettingsLinkTile(
          icon: Icons.mail_outline,
          title: 'お問い合わせ',
          subtitle: AppLinks.contactEmail,
          showDivider: false,
          onTap: () => _openExternalLink(AppLinks.contactUri),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const SettingsSectionHeader(title: '外観'),
          SettingsGroup(
            children: [
              _ThemeTile(
                label: 'ライトモード',
                icon: Icons.light_mode_outlined,
                selected: widget.themeMode == ThemeMode.light,
                onTap: () => widget.onThemeModeChanged(ThemeMode.light),
                showDivider: true,
              ),
              _ThemeTile(
                label: 'ダークモード',
                icon: Icons.dark_mode_outlined,
                selected: widget.themeMode == ThemeMode.dark,
                onTap: () => widget.onThemeModeChanged(ThemeMode.dark),
                showDivider: true,
              ),
              _ThemeTile(
                label: 'システム設定に従う',
                icon: Icons.brightness_auto_outlined,
                selected: widget.themeMode == ThemeMode.system,
                onTap: () => widget.onThemeModeChanged(ThemeMode.system),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionHeader(title: '完了タスク'),
          SettingsGroup(
            children: [
              for (final (index, retention)
                  in CompletedTaskRetention.values.indexed)
                _RetentionTile(
                  label: retention.label,
                  selected: widget.completedTaskRetention == retention,
                  showDivider:
                      index < CompletedTaskRetention.values.length - 1,
                  onTap: () =>
                      widget.onCompletedTaskRetentionChanged(retention),
                ),
              Divider(height: 1, color: colors.separator),
              ListTile(
                title: Text(
                  '完了タスクを一括削除',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                trailing: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onTap: _confirmDeleteAllCompletedTasks,
              ),
            ],
          ),
          const SettingsSectionHeader(title: 'サウンドと触覚'),
          SettingsGroup(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('効果音'),
                subtitle: const Text('登録・完了・整理時の音'),
                value: widget.feedbackPreferences.soundEnabled,
                onChanged: (enabled) {
                  widget.onFeedbackPreferencesChanged(
                    widget.feedbackPreferences.copyWith(
                      soundEnabled: enabled,
                    ),
                  );
                },
              ),
              Divider(height: 1, indent: 56, color: colors.separator),
              SwitchListTile(
                secondary: const Icon(Icons.vibration_outlined),
                title: const Text('ハプティック'),
                subtitle: const Text('登録・完了・整理時の振動'),
                value: widget.feedbackPreferences.hapticEnabled,
                onChanged: (enabled) {
                  widget.onFeedbackPreferencesChanged(
                    widget.feedbackPreferences.copyWith(
                      hapticEnabled: enabled,
                    ),
                  );
                },
              ),
            ],
          ),
          const SettingsSectionHeader(title: '通知'),
          SettingsGroup(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('通知'),
                subtitle: const Text('時間指定タスクの開始前通知'),
                value: widget.notificationPreferences.enabled,
                onChanged: (enabled) {
                  widget.onNotificationPreferencesChanged(
                    widget.notificationPreferences.copyWith(
                      enabled: enabled,
                    ),
                  );
                },
              ),
              Divider(height: 1, indent: 56, color: colors.separator),
              const ListTile(
                title: Text('通知タイミング'),
              ),
              for (final (index, leadTime)
                  in NotificationLeadTime.values.indexed)
                _NotificationLeadTimeTile(
                  label: leadTime.label,
                  selected:
                      widget.notificationPreferences.leadTime == leadTime,
                  showDivider:
                      index < NotificationLeadTime.values.length - 1,
                  enabled: widget.notificationPreferences.enabled,
                  onTap: () {
                    widget.onNotificationPreferencesChanged(
                      widget.notificationPreferences.copyWith(
                        leadTime: leadTime,
                      ),
                    );
                  },
                ),
            ],
          ),
          if (kCloudAuthEnabled) ...[
            const SettingsSectionHeader(title: 'アカウント'),
            StreamBuilder<AuthUser?>(
              stream: widget.authService.authStateChanges,
              initialData: widget.authService.currentUser,
              builder: (context, snapshot) {
                return _accountSection(snapshot.data);
              },
            ),
          ],
          const SettingsSectionHeader(title: 'アプリについて'),
          _aboutSection(),
          const SettingsSectionHeader(title: 'サポート'),
          _supportSection(),
          if (kFirebaseEnabled) ...[
            const SizedBox(height: 16),
            const DebugCrashlyticsPanel(),
          ],
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

class _NotificationLeadTimeTile extends StatelessWidget {
  const _NotificationLeadTimeTile({
    required this.label,
    required this.selected,
    required this.showDivider,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showDivider;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Column(
      children: [
        ListTile(
          enabled: enabled,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_off_outlined,
            color: selected && enabled
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          title: Text(label),
          onTap: enabled ? onTap : null,
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
