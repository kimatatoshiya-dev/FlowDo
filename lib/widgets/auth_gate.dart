import 'package:flutter/material.dart';

import '../screens/login_page.dart';
import '../debug/startup_trace.dart';
import '../services/auth/auth_service.dart';

/// 認証状態に応じてログイン画面 / メイン画面を切り替える
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
    return StreamBuilder<AuthUser?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        startupTrace(
          'AuthGate.build',
          'connectionState=${snapshot.connectionState}, '
          'hasData=${snapshot.hasData}, '
          'data=${snapshot.data?.uid ?? 'null'}, '
          'currentUser=${authService.currentUser?.uid ?? 'null'}',
        );
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null &&
            authService.currentUser == null) {
          startupTrace('AuthGate -> waiting spinner');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data ?? authService.currentUser;
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
