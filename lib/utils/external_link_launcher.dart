import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 外部ブラウザ / メールアプリを開く
class ExternalLinkLauncher {
  ExternalLinkLauncher._();

  static Future<bool> launch(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showError(context);
      }
      return launched;
    } catch (_) {
      if (context.mounted) {
        _showError(context);
      }
      return false;
    }
  }

  static void _showError(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('リンクを開けませんでした'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
