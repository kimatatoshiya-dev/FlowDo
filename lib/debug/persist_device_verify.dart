import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/category_item.dart';
import '../models/task.dart';
import '../services/app_storage.dart';

/// 実機永続化検証（--dart-define=PERSIST_DEVICE_VERIFY=true のみ）
const kPersistDeviceVerify = bool.fromEnvironment('PERSIST_DEVICE_VERIFY');

/// devicectl コールド起動検証用: Firebase 等をスキップして SP だけ確認
const kPersistVerifyOnly = bool.fromEnvironment('PERSIST_VERIFY_ONLY');

/// main() 冒頭で true を返したら通常 bootstrap をスキップする
Future<bool> enterPersistVerifyOnlyMode() async {
  if (!kPersistDeviceVerify || !kPersistVerifyOnly) return false;
  runApp(const _PersistVerifyShell());
  return true;
}

class _PersistVerifyShell extends StatelessWidget {
  const _PersistVerifyShell();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(runPersistDeviceVerify());
          });
          return const ColoredBox(color: Colors.black);
        },
      ),
    );
  }
}

/// 追加 → 完全終了 → コールド起動 の SP 保存/復元を検証する
Future<void> runPersistDeviceVerify() async {
  if (!kPersistDeviceVerify) return;

  var marker = _resolvePersistMarker();
  if (marker.isEmpty) {
    marker = 'persist-verify-${DateTime.now().millisecondsSinceEpoch}';
  }

  for (var attempt = 1; attempt <= 60; attempt++) {
    final ready = await AppStorage.ensureReady();
    if (ready) break;
    if (attempt == 60) {
      // ignore: avoid_print
      print('[FlowDoPersistResult] fail reason=storage_not_ready marker=$marker');
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  final tasks = await AppStorage.loadTasks(
    forceRetry: true,
    diagSource: 'persist_device_verify',
    logStartupDiag: true,
  );
  final hasMarker = tasks.any((task) => task.title == marker);

  if (!hasMarker) {
    final updated = List<Task>.from(tasks)
      ..insert(
        0,
        Task.create(title: marker, categoryId: CategoryItem.uncategorizedId),
      );
    Task.syncNextId(updated);
    await AppStorage.saveTasks(updated);
    final saved = await AppStorage.loadTasks(
      forceRetry: true,
      diagSource: 'persist_device_verify save_check',
    );
    final ok = saved.any((task) => task.title == marker);
    // ignore: avoid_print
    print(
      '[FlowDoPersistResult] ${ok ? 'save_ok' : 'save_fail'} '
      'marker=$marker count=${saved.length}',
    );
    return;
  }

  // ignore: avoid_print
  print(
    '[FlowDoPersistResult] restore_ok marker=$marker count=${tasks.length}',
  );
}

String _resolvePersistMarker() {
  for (final arg in Platform.executableArguments) {
    const prefix = '--persist-marker=';
    if (arg.startsWith(prefix)) {
      return arg.substring(prefix.length);
    }
  }
  final fromEnv = Platform.environment['FLOWDO_PERSIST_MARKER'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  return const String.fromEnvironment('PERSIST_MARKER');
}
