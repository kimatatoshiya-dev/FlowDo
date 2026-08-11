import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/config/app_links.dart';

void main() {
  test('利用規約・プライバシー・お問い合わせの URL が設定されている', () {
    expect(AppLinks.termsOfServiceUri.toString(), AppLinks.termsOfServiceUrl);
    expect(AppLinks.privacyPolicyUri.toString(), AppLinks.privacyPolicyUrl);
    expect(AppLinks.contactUri.toString(), AppLinks.contactPageUrl);

    expect(AppLinks.termsOfServiceUri.scheme, 'https');
    expect(AppLinks.privacyPolicyUri.scheme, 'https');
    expect(AppLinks.contactUri.scheme, 'https');
    expect(AppLinks.contactEmail, 'support@flowdo.app');
  });
}
