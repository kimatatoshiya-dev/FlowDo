/// アプリ内から開く公式サイト URL。
abstract final class AppLinks {
  static const termsOfServiceUrl =
      'https://kimatatoshiya-dev.github.io/FlowDo/terms/';
  static const privacyPolicyUrl =
      'https://kimatatoshiya-dev.github.io/FlowDo/privacy/';
  static const contactPageUrl =
      'https://kimatatoshiya-dev.github.io/FlowDo/contact.html';
  static const contactEmail = 'support@flowdo.app';

  static Uri get termsOfServiceUri => Uri.parse(termsOfServiceUrl);

  static Uri get privacyPolicyUri => Uri.parse(privacyPolicyUrl);

  static Uri get contactUri => Uri.parse(contactPageUrl);
}
