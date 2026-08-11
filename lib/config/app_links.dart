/// ストア公開前に実際の URL / 連絡先へ差し替えてください。
abstract final class AppLinks {
  static const termsOfServiceUrl = 'https://flowdo.app/terms';
  static const privacyPolicyUrl = 'https://flowdo.app/privacy';
  static const contactEmail = 'support@flowdo.app';

  static Uri get termsOfServiceUri => Uri.parse(termsOfServiceUrl);

  static Uri get privacyPolicyUri => Uri.parse(privacyPolicyUrl);

  static Uri get contactUri => Uri(
        scheme: 'mailto',
        path: contactEmail,
        query: 'subject=${Uri.encodeComponent('FlowDo お問い合わせ')}',
      );
}
