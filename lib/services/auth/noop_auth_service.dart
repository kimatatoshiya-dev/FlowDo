import 'dart:async';

import 'auth_service.dart';

/// テスト用: 常にログイン済みとして扱う AuthService
class NoOpAuthService implements AuthService {
  const NoOpAuthService({this.signedIn = true});

  final bool signedIn;

  static const _testUser = AuthUser(
    uid: 'test-user',
    email: 'test@flowdo.local',
    displayName: 'Test User',
    providerId: 'test',
  );

  @override
  Stream<AuthUser?> get authStateChanges {
    return Stream<AuthUser?>.value(signedIn ? _testUser : null);
  }

  @override
  AuthUser? get currentUser => signedIn ? _testUser : null;

  @override
  Future<void> waitForInitialAuthState() async {
    await authStateChanges.first;
  }

  @override
  Future<bool> get isAppleSignInAvailable async => false;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> signOut() async {}
}
