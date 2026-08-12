import 'package:flutter/foundation.dart';

import '../models/task.dart';

const _tag = '[FlowDoStorage]';

/// タスク永続化の診断ログ（開発時のデータ消失調査用）
void logTaskStorage(String message) {
  if (!kDebugMode) return;
  debugPrint('$_tag $message');
}

/// 起動時のタスク復元結果をログ出力する
void logStartupTaskRestore({
  required bool storageReady,
  required List<Task> tasks,
  required bool hadPersistedPayload,
  int? payloadBytes,
  String? errorMessage,
}) {
  if (!kDebugMode) return;

  final buffer = StringBuffer('startup restore: ');
  buffer.write('storageReady=$storageReady');
  buffer.write(', hadPersistedPayload=$hadPersistedPayload');
  if (payloadBytes != null) {
    buffer.write(', payloadBytes=$payloadBytes');
  }
  buffer.write(', taskCount=${tasks.length}');

  if (errorMessage != null) {
    buffer.write(', error=$errorMessage');
  }

  if (tasks.isNotEmpty) {
    final preview = tasks
        .take(5)
        .map((task) => '#${task.id} "${task.title}"')
        .join(', ');
    buffer.write(', preview=[$preview');
    if (tasks.length > 5) {
      buffer.write(', +${tasks.length - 5} more');
    }
    buffer.write(']');
  }

  debugPrint('$_tag $buffer');
}

/// 自動保存（通常利用）のログ
void logTaskAutoSave({
  required int taskCount,
  required bool storageReady,
  required bool verified,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '$_tag auto-save: taskCount=$taskCount, storageReady=$storageReady, verified=$verified',
  );
}
