import 'package:flutter/material.dart';

import '../screens/login_page.dart';
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data ?? authService.currentUser;
        if (user != null) {
          return signedInBuilder(context);
        }

        return LoginPage(authService: authService);
      },
    );
  }
}
