import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/crash_reporting.dart';
import '../theme/app_theme.dart';

/// Debug ビルド専用: Crashlytics 動作確認パネル
class DebugCrashlyticsPanel extends StatelessWidget {
  const DebugCrashlyticsPanel({super.key});

  Future<void> _showResult(BuildContext context, String message) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crashlytics テスト'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmNativeFatal(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Native Fatal テスト'),
        content: const Text(
          'Release ビルドでのみ Crashlytics に送信されます。\n'
          'アプリが強制終了します。続行しますか？',
        ),
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
            child: const Text('クラッシュ実行'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      testCrashlyticsNativeFatal();
    } on StateError catch (error) {
      if (!context.mounted) return;
      await _showResult(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            'Debug',
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
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Crash Test: Non-Fatal'),
                  subtitle: Text(
                    isCrashReportingEnabled
                        ? 'Release: Crashlytics に送信'
                        : 'Debug: 送信なし（Release で確認）',
                  ),
                  onTap: () async {
                    final message = await testCrashlyticsNonFatal();
                    if (context.mounted) await _showResult(context, message);
                  },
                ),
                Divider(height: 1, indent: 56, color: colors.separator),
                ListTile(
                  leading: const Icon(Icons.sync_problem_outlined),
                  title: const Text('Crash Test: Async Non-Fatal'),
                  subtitle: const Text('Zone 経由の非同期エラー'),
                  onTap: () async {
                    final message = await testCrashlyticsAsyncNonFatal();
                    if (context.mounted) await _showResult(context, message);
                  },
                ),
                Divider(height: 1, indent: 56, color: colors.separator),
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Crash Test: Flutter Fatal'),
                  subtitle: const Text('recordFlutterFatalError'),
                  onTap: () async {
                    final message = await testCrashlyticsFlutterFatal();
                    if (context.mounted) await _showResult(context, message);
                  },
                ),
                Divider(height: 1, indent: 56, color: colors.separator),
                ListTile(
                  leading: Icon(
                    Icons.warning_amber_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Crash Test: Native Fatal',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text('アプリ強制終了（Release のみ送信）'),
                  onTap: () => _confirmNativeFatal(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
