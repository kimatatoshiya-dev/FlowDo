import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../services/app_storage.dart';
import '../services/tasks/task_repository.dart';

bool get kPersistDeviceVerifyEnabled =>
    const bool.fromEnvironment('FLOWDO_VERIFY_PERSIST');

/// 実機検証 UI 用
final ValueNotifier<Map<String, dynamic>?> persistVerifyReportNotifier =
    ValueNotifier<Map<String, dynamic>?>(null);

/// 実機検証用: 起動・保存・再起動の結果を SharedPreferences とログに出力する。
Future<void> runPersistenceDeviceVerification(TaskRepository repository) async {
  if (!kPersistDeviceVerifyEnabled) {
    return;
  }

  try {
    final report = await AppStorage.loadPersistVerifyReport();
    report['launchCount'] = (report['launchCount'] as int? ?? 0) + 1;
    report['lastLaunchAt'] = DateTime.now().toIso8601String();

    final storageReady = AppStorage.isStorageReady;
    report['storageReady'] = storageReady;

    final snapshot = await AppStorage.readPersistedTaskSnapshot();
    report['startup'] = {
      'storageReady': storageReady,
      'hadPersistedPayload': snapshot.hadPersistedPayload,
      'taskCount': snapshot.taskCount,
    };

    if (snapshot.taskCount == 0) {
      final task = Task.create(title: '永続化検証', categoryId: 'work');
      debugPrint('[FlowDoPersistVerify] creating task id=${task.id}');
      await repository.createTask(task);

      final saveSnapshot = await AppStorage.readPersistedTaskSnapshot();
      final setStringResult =
          saveSnapshot.hadPersistedPayload && saveSnapshot.taskCount >= 1;
      final verified =
          setStringResult && saveSnapshot.rawJson.contains('${task.id}');
      report['save'] = {
        'setStringResult': setStringResult,
        'verified': verified,
        'savedTaskCount': saveSnapshot.taskCount,
      };
      debugPrint(
        '[FlowDoPersistVerify] save setStringResult=$setStringResult '
        'verified=$verified taskCount=${saveSnapshot.taskCount}',
      );
    } else {
      debugPrint(
        '[FlowDoPersistVerify] restart load taskCount=${snapshot.taskCount} '
        'hadPersistedPayload=${snapshot.hadPersistedPayload}',
      );
    }

    report['passed'] = _evaluatePassed(report);
    await AppStorage.savePersistVerifyReport(report);
    persistVerifyReportNotifier.value = Map<String, dynamic>.from(report);
    debugPrint('[FlowDoPersistVerifyReport] ${jsonEncode(report)}');
    debugPrint('[FlowDoPersistVerify] passed=${report['passed']}');
  } catch (error, stack) {
    debugPrint('[FlowDoPersistVerify] failed: $error');
    debugPrint(stack.toString());
  }
}

bool _evaluatePassed(Map<String, dynamic> report) {
  final storageReady = report['storageReady'] == true;
  final save = report['save'] as Map<String, dynamic>?;
  final startup = report['startup'] as Map<String, dynamic>?;
  final saveOk = save != null &&
      save['setStringResult'] == true &&
      save['verified'] == true;
  final restartOk = startup != null &&
      startup['hadPersistedPayload'] == true &&
      (startup['taskCount'] as int? ?? 0) >= 1;
  return storageReady && saveOk && restartOk;
}
