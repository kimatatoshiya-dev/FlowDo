import 'package:flutter/material.dart';

import '../config/app_features.dart';
import '../screens/login_page.dart';
import '../debug/startup_trace.dart';
import '../services/auth/auth_service.dart';

/// 認証状態に応じてログイン画面 / メイン画面を切り替える。
///
/// ゲストモード有効時は起動直後からメイン画面を表示する。
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.signedInBuilder,
  });

  final AuthService authService;
  final WidgetBuilder signedInBuilder;

  @override
  Widget build(BuildContext context) {
    if (kGuestModeEnabled || !kCloudAuthEnabled) {
      return signedInBuilder(context);
    }

    return StreamBuilder<AuthUser?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        startupTrace(
          'AuthGate.build',
          'connectionState=${snapshot.connectionState}, '
          'hasData=${snapshot.hasData}, '
          'hasError=${snapshot.hasError}, '
          'data=${snapshot.data?.uid ?? 'null'}, '
          'currentUser=${authService.currentUser?.uid ?? 'null'}',
        );
        if (snapshot.connectionState == ConnectionState.waiting) {
          startupTrace('AuthGate -> waiting spinner');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          startupTrace('AuthGate -> auth stream error', snapshot.error);
          return LoginPage(authService: authService);
        }

        final user = snapshot.data;
        if (user != null) {
          startupTrace('AuthGate -> signedInBuilder', 'uid=${user.uid}');
          return signedInBuilder(context);
        }

        startupTrace('AuthGate -> LoginPage');
        return LoginPage(authService: authService);
      },
    );
  }
}
