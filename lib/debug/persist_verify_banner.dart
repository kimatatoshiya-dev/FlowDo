import 'package:flutter/material.dart';

import 'persist_device_verify.dart';

/// 実機検証用: 画面上に永続化診断結果を表示する。
class PersistVerifyOverlay extends StatelessWidget {
  const PersistVerifyOverlay({super.key, required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final startup = report['startup'] as Map<String, dynamic>? ?? const {};
    final save = report['save'] as Map<String, dynamic>? ?? const {};
    final lines = <String>[
      'PersistDiag storageReady=${report['storageReady'] == true}',
      if (save.isNotEmpty)
        'PersistDiag setStringResult=${save['setStringResult'] == true} '
        'verified=${save['verified'] == true}',
      'PersistDiag hadPersistedPayload=${startup['hadPersistedPayload'] == true} '
      'taskCount=${startup['taskCount'] ?? 0}',
      'PersistDiag passed=${report['passed'] == true}',
    ];

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.black.withValues(alpha: 0.82),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Menlo',
                height: 1.35,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in lines) Text(line),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget wrapWithPersistVerifyOverlay({
  required Widget child,
}) {
  if (!kPersistDeviceVerifyEnabled) {
    return child;
  }

  return ValueListenableBuilder<Map<String, dynamic>?>(
    valueListenable: persistVerifyReportNotifier,
    builder: (context, report, _) {
      if (report == null) {
        return child;
      }
      return Stack(
        children: [
          child,
          PersistVerifyOverlay(report: report),
        ],
      );
    },
  );
}
