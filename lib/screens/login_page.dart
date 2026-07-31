import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/auth_sign_in_debug.dart';
import '../theme/app_theme.dart';
import '../widgets/flowdo_mark.dart';

/// 未ログイン時に表示するサインイン画面
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authService,
  });

  final AuthService authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _appleSignInAvailable = false;
  String? _debugError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAppleAvailability());
  }

  Future<void> _loadAppleAvailability() async {
    final available = await widget.authService.isAppleSignInAvailable;
    if (!mounted) return;
    setState(() => _appleSignInAvailable = available);
  }

  Future<void> _runSignIn(Future<void> Function() action) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _debugError = null;
    });

    try {
      await action();
    } on GoogleSignInException catch (error, stackTrace) {
      if (error.code == GoogleSignInExceptionCode.canceled) return;
      _handleSignInError(error, stackTrace);
      rethrow;
    } on SignInWithAppleAuthorizationException catch (error, stackTrace) {
      if (error.code == AuthorizationErrorCode.canceled) return;
      _handleSignInError(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      _handleSignInError(error, stackTrace);
      rethrow;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSignInError(Object error, StackTrace stackTrace) {
    AuthSignInDebug.log(error, stackTrace);
    if (!mounted) return;
    setState(() => _debugError = AuthSignInDebug.uiMessage(error));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FlowDoMark(size: 56, intensity: 0.9),
                  const SizedBox(height: 20),
                  Text(
                    'FlowDo',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '考えずに入力。整理はAI。行動に集中。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.secondaryLabel,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 40),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    _SignInButton(
                      label: 'Google で続ける',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: () => _runSignIn(widget.authService.signInWithGoogle),
                    ),
                    if (_appleSignInAvailable) ...[
                      const SizedBox(height: 12),
                      _SignInButton(
                        label: 'Apple で続ける',
                        icon: Icons.apple,
                        onPressed: () =>
                            _runSignIn(widget.authService.signInWithApple),
                        filled: true,
                      ),
                    ],
                  ],
                  if (_debugError != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _debugError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      backgroundColor: colorScheme.surface,
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Text(label),
      ],
    );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
