import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/services/app_version_info.dart';

void main() {
  test('displayLabel はバージョンとビルド番号を含む', () {
    const info = AppVersionInfo(version: '1.0.0', buildNumber: '42');

    expect(info.displayLabel, 'v1.0.0 (42)');
    expect(info.shortLabel, 'v1.0.0');
  });
}
