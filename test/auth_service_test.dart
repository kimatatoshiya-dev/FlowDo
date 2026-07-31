import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/services/auth/noop_auth_service.dart';

void main() {
  group('NoOpAuthService', () {
    const signedInService = NoOpAuthService();
    const signedOutService = NoOpAuthService(signedIn: false);

    test('signedIn=true ではユーザーを返す', () async {
      await expectLater(
        signedInService.authStateChanges,
        emits(isNotNull),
      );
      expect(signedInService.currentUser?.uid, 'test-user');
    });

    test('signedIn=false では未ログイン', () async {
      await expectLater(
        signedOutService.authStateChanges,
        emits(null),
      );
      expect(signedOutService.currentUser, isNull);
    });

    test('サインイン操作は例外を投げない', () async {
      await expectLater(signedInService.signInWithGoogle(), completes);
      await expectLater(signedInService.signInWithApple(), completes);
      await expectLater(signedInService.signOut(), completes);
    });
  });
}
