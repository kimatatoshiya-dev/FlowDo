import 'package:flutter/foundation.dart';

/// Temporary startup instrumentation. Remove after white-screen investigation.
void startupTrace(String step, [Object? detail]) {
  final message = '[FlowDoStartup] $step${detail == null ? '' : ': $detail'}';
  debugPrint(message);
  // Visible in Xcode device console even when flutter run cannot attach.
  // ignore: avoid_print
  print(message);
}
