/// Firebase Auth ユーザーのアプリ向け表現（個人情報は UI 表示に必要な最小限のみ）
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.providerId,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? providerId;

  String get label {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim();
    }
    return 'ログイン中';
  }
}
