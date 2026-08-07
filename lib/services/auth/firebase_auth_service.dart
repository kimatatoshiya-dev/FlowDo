import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'apple_sign_in_config.dart';
import 'auth_service.dart';
import 'auth_sign_in_debug.dart';
import 'google_sign_in_config.dart';
import '../../firebase_options.dart';

/// Firebase Authentication 実装
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;
  bool _googleSignInInitialized = false;

  @override
  Stream<AuthUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  AuthUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Future<void> waitForInitialAuthState() async {
    try {
      await _firebaseAuth.authStateChanges().first.timeout(
        const Duration(seconds: 10),
      );
    } on TimeoutException {
      debugPrint(
        '[Auth] waitForInitialAuthState timed out; '
        'continuing with currentUser=${_firebaseAuth.currentUser?.uid}',
      );
    }
  }

  @override
  Future<bool> get isAppleSignInAvailable async {
    if (!isAppleSignInEnabledForBuild) return false;
    if (!Platform.isIOS) return false;
    return SignInWithApple.isAvailable();
  }

  @override
  Future<void> signInWithGoogle() async {
    debugPrint('[Auth] Google sign-in: initialize start');
    await _ensureGoogleSignInInitialized();
    debugPrint('[Auth] Google sign-in: authenticate start');

    late final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } catch (error, stackTrace) {
      AuthSignInDebug.log(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }

    debugPrint('[Auth] Google sign-in: user=${googleUser.email}');
    final idToken = googleUser.authentication.idToken;
    debugPrint(
      '[Auth] Google tokens: idToken=${idToken != null ? 'present' : 'null'}',
    );

    if (idToken == null) {
      final error = FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Google サインインの ID トークンを取得できませんでした。',
      );
      AuthSignInDebug.log(error);
      throw error;
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    debugPrint('[Auth] Firebase signInWithCredential start');
    try {
      await _firebaseAuth.signInWithCredential(credential);
    } catch (error, stackTrace) {
      AuthSignInDebug.log(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
    debugPrint('[Auth] Google sign-in: success uid=${_firebaseAuth.currentUser?.uid}');
  }

  @override
  Future<void> signInWithApple() async {
    if (!await isAppleSignInAvailable) {
      throw FirebaseAuthException(
        code: 'apple-sign-in-unavailable',
        message: 'この端末では Sign in with Apple を利用できません。',
      );
    }

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Apple サインインの ID トークンを取得できませんでした。',
      );
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      accessToken: appleCredential.authorizationCode,
    );
    final userCredential =
        await _firebaseAuth.signInWithCredential(oauthCredential);

    final displayName = _appleDisplayName(appleCredential);
    final user = userCredential.user;
    if (displayName != null &&
        user != null &&
        (user.displayName == null || user.displayName!.trim().isEmpty)) {
      await user.updateDisplayName(displayName);
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      if (_googleSignInInitialized) GoogleSignIn.instance.signOut(),
    ]);
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS || Platform.isMacOS
            ? DefaultFirebaseOptions.currentPlatform.iosClientId
            : null,
        serverClientId: kFirebaseAuthWebClientId,
      );
      _googleSignInInitialized = true;
      debugPrint('[Auth] GoogleSignIn.initialize: success');
    } catch (error, stackTrace) {
      AuthSignInDebug.log(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;

    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      providerId: user.providerData.isEmpty
          ? null
          : user.providerData.first.providerId,
    );
  }

  String? _appleDisplayName(AuthorizationCredentialAppleID credential) {
    final parts = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }
}
