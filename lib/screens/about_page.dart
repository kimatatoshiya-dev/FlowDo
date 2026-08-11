import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_features.dart';
import '../services/app_version_info.dart';
import '../theme/app_theme.dart';
import '../widgets/flowdo_mark.dart';

/// アプリについて画面
class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    this.versionInfo,
  });

  final AppVersionInfo? versionInfo;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  AppVersionInfo? _versionInfo;

  @override
  void initState() {
    super.initState();
    _versionInfo = widget.versionInfo;
    if (_versionInfo == null) {
      unawaited(_loadVersion());
    }
  }

  Future<void> _loadVersion() async {
    final info = await AppVersionInfo.load();
    if (!mounted) return;
    setState(() => _versionInfo = info);
  }

  String get _tagline => kGuestModeEnabled
      ? '考えずに入力。行動に集中。'
      : '考えずに入力。整理はAI。行動に集中。';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final versionLabel = _versionInfo?.displayLabel ?? '読み込み中…';

    return Scaffold(
      appBar: AppBar(title: const Text('アプリについて')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        children: [
          Center(
            child: Column(
              children: [
                const FlowDoMark(size: 56, intensity: 1),
                const SizedBox(height: 16),
                Text(
                  'FlowDo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.secondaryLabel,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Material(
            color: colors.groupedSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'FlowDo は、頭に浮かんだことをそのまま書き出し、'
                'あとからカテゴリーへ整理するタスクアプリです。\n\n'
                '入力のハードルを下げ、やるべきことに集中できるよう、'
                'シンプルな操作感を大切にしています。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: colors.secondaryLabel,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              versionLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.secondaryLabel,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
