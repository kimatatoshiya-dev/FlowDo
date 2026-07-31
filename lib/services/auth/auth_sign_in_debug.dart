import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// サインイン失敗時の詳細ログと UI 表示用テキストを生成する（一時的なデバッグ用）
class AuthSignInDebug {
  static String describe(Object error, [StackTrace? stackTrace]) {
    final buffer = StringBuffer();

    if (error is FirebaseAuthException) {
      buffer.writeln('[FirebaseAuthException]');
      buffer.writeln('code: ${error.code}');
      buffer.writeln('message: ${error.message ?? '(null)'}');
      buffer.writeln('email: ${error.email ?? '(null)'}');
      buffer.writeln('credential: ${error.credential ?? '(null)'}');
      buffer.writeln('plugin: ${error.plugin}');
      buffer.writeln('stackTrace: ${error.stackTrace ?? '(null)'}');
    } else if (error is PlatformException) {
      buffer.writeln('[PlatformException]');
      buffer.writeln('code: ${error.code}');
      buffer.writeln('message: ${error.message ?? '(null)'}');
      buffer.writeln('details: ${error.details ?? '(null)'}');
      buffer.writeln('stacktrace: ${error.stacktrace ?? '(null)'}');
    } else if (error is GoogleSignInException) {
      buffer.writeln('[GoogleSignInException]');
      buffer.writeln('code: ${error.code.name} (${error.code})');
      buffer.writeln('description: ${error.description ?? '(null)'}');
      buffer.writeln('details: ${error.details ?? '(null)'}');
    } else {
      buffer.writeln('[${error.runtimeType}]');
      buffer.writeln(error.toString());
    }

    if (stackTrace != null) {
      buffer.writeln('--- stack trace ---');
      buffer.writeln(stackTrace);
    }

    return buffer.toString();
  }

  static String uiMessage(Object error) {
    if (error is FirebaseAuthException) {
      return 'FirebaseAuthException\n'
          'code: ${error.code}\n'
          'message: ${error.message ?? '(null)'}';
    }
    if (error is PlatformException) {
      return 'PlatformException\n'
          'code: ${error.code}\n'
          'message: ${error.message ?? '(null)'}';
    }
    if (error is GoogleSignInException) {
      return 'GoogleSignInException\n'
          'code: ${error.code.name}\n'
          'description: ${error.description ?? '(null)'}';
    }
    return '${error.runtimeType}: $error';
  }

  static void log(Object error, [StackTrace? stackTrace]) {
    debugPrint('=== Auth sign-in error ===');
    debugPrint(describe(error, stackTrace));
    debugPrint('==========================');
  }
}
