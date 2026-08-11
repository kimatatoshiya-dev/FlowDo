import 'package:package_info_plus/package_info_plus.dart';

/// アプリのバージョン情報（pubspec.yaml / ビルド設定から取得）
class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
  });

  final String version;
  final String buildNumber;

  String get displayLabel => 'v$version ($buildNumber)';

  String get shortLabel => 'v$version';

  static Future<AppVersionInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(
      version: info.version,
      buildNumber: info.buildNumber,
    );
  }
}
