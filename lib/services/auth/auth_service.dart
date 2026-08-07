import 'auth_user.dart';

export 'auth_user.dart';
export 'firebase_auth_service.dart';
export 'noop_auth_service.dart';

/// Firebase Authentication の抽象インターフェース
abstract class AuthService {
  Stream<AuthUser?> get authStateChanges;

  AuthUser? get currentUser;

  /// コールドスタート時の Firebase Auth セッション復元が完了するまで待つ
  Future<void> waitForInitialAuthState();

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> signOut();

  /// Sign in with Apple を表示してよいプラットフォームか
  Future<bool> get isAppleSignInAvailable;
}
