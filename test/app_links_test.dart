import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/config/app_links.dart';

void main() {
  test('利用規約とプライバシーポリシーの URL が設定されている', () {
    expect(AppLinks.termsOfServiceUri.scheme, 'https');
    expect(AppLinks.privacyPolicyUri.scheme, 'https');
    expect(AppLinks.contactUri.scheme, 'mailto');
    expect(AppLinks.contactUri.path, AppLinks.contactEmail);
  });
}
